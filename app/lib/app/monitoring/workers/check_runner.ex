defmodule FF.Monitoring.Workers.CheckRunner do
  @moduledoc """
  Oban worker that executes a single uptime check and reschedules itself
  for the next run. Self-rescheduling means each job reads the check's
  current `interval_seconds` and `paused` flag at execution time, so
  config changes apply on the next run without external cron updates.

  ## Parallel execution guard

  When the Reaper cancels a stuck job, the BEAM process keeps running —
  Oban cancel only flips DB state. The reaper then calls `schedule_initial`,
  which creates a replacement job. To prevent stale completions from the
  old process, CheckRunner stamps `current_job_id` on the check at the
  start of `run/1`. Before writing results, it re-reads the check and
  verifies `current_job_id` still matches. If a newer job has claimed
  the check, the old runner discards its results.

  This is safe because the Oban unique constraint excludes `:executing`,
  so the replacement job can be inserted while the old one is still
  (nominally) executing.
  """

  use Oban.Worker,
    queue: :checks,
    max_attempts: 1,
    unique: [
      keys: [:check_id],
      states: [:available, :scheduled, :retryable]
    ]

  require Logger

  alias FF.Monitoring
  alias FF.Monitoring.{Check, IncidentLifecycle, Scheduler}
  alias FF.Repo

  @default_timeout_ms 30_000

  @impl Oban.Worker
  def perform(%Oban.Job{id: job_id, args: %{"check_id" => check_id}}) do
    try do
      run_if_active(check_id, job_id)
    after
      reschedule_if_active(check_id)
    end
  end

  defp run_if_active(check_id, job_id) do
    case Repo.get(Check, check_id) do
      nil -> :ok
      %Check{paused: true} -> :ok
      %Check{} = check -> run(check, job_id)
    end
  end

  defp reschedule_if_active(check_id) do
    case Repo.get(Check, check_id) do
      nil -> :ok
      %Check{paused: true} -> :ok
      check -> Scheduler.schedule_next(check)
    end
  end

  defp run(%Check{} = check, job_id) do
    # Claim this check by stamping our job_id. If the reaper cancels us
    # and schedules a replacement, the new runner will overwrite this,
    # and our post-run verification will detect the mismatch.
    Monitoring.update_runtime_fields(check, %{current_job_id: job_id})

    started_at = System.monotonic_time(:millisecond)
    outcome = execute_request(check)
    elapsed_ms = max(System.monotonic_time(:millisecond) - started_at, 0)
    checked_at = DateTime.utc_now(:second)

    # Re-read the check to verify we still own it. A concurrent reaper
    # cancel + reschedule may have handed the check to a new job.
    case Repo.get(Check, check.id) do
      nil ->
        :ok

      %Check{current_job_id: ^job_id} = fresh_check ->
        apply_result(fresh_check, outcome, elapsed_ms, checked_at)

      %Check{current_job_id: other_job_id} ->
        Logger.warning(
          "CheckRunner stale completion: job #{job_id} lost claim to job #{other_job_id} for check #{check.id}"
        )

        :ok
    end
  end

  defp apply_result(%Check{} = check, outcome, elapsed_ms, checked_at) do
    case Monitoring.create_check_result(
           check,
           build_result_attrs(outcome, elapsed_ms, checked_at)
         ) do
      {:ok, %{} = result} ->
        Monitoring.broadcast_check_result_created(check, result)

        updated_check = apply_outcome(check, outcome, checked_at)

        case outcome do
          {:up, _} -> IncidentLifecycle.handle_recovery(updated_check)
          {:down, _, _} -> maybe_open_incident(updated_check, result)
        end

      {:error, changeset} ->
        Logger.error(
          "CheckRunner failed to create result for check #{check.id}: #{inspect(changeset.errors)}"
        )
    end

    :ok
  end

  defp maybe_open_incident(%Check{} = check, result) do
    if check.consecutive_failures >= check.failure_threshold do
      IncidentLifecycle.create_or_reopen_incident(check, result)
    end
  end

  defp execute_request(%Check{} = check) do
    method = check.method || :get

    timeout_ms =
      Application.get_env(:app, __MODULE__, [])
      |> Keyword.get(:timeout_ms, @default_timeout_ms)

    request_options = [
      method: method,
      url: check.url,
      receive_timeout: timeout_ms,
      connect_options: [timeout: timeout_ms],
      retry: false,
      decode_body: false
    ]

    try do
      case http_client().request(request_options) do
        {:ok, %{status: status, body: body}} ->
          evaluate_response(check, status, body)

        {:error, reason} ->
          {:down, nil, format_error(reason)}
      end
    rescue
      error -> {:down, nil, "exception: #{inspect(error)}"}
    catch
      :exit, reason -> {:down, nil, "exit: #{inspect(reason)}"}
    end
  end

  defp evaluate_response(%Check{expected_status: expected}, status, _body)
       when status != expected do
    {:down, status, "expected status #{expected}, got #{status}"}
  end

  defp evaluate_response(%Check{keyword: nil}, status, _body), do: {:up, status}

  defp evaluate_response(%Check{keyword: keyword, keyword_absence: false}, status, body) do
    if body_string(body) =~ keyword do
      {:up, status}
    else
      {:down, status, "keyword not found: #{keyword}"}
    end
  end

  defp evaluate_response(%Check{keyword: keyword, keyword_absence: true}, status, body) do
    if body_string(body) =~ keyword do
      {:down, status, "keyword present: #{keyword}"}
    else
      {:up, status}
    end
  end

  defp body_string(body) when is_binary(body), do: body
  defp body_string(body), do: inspect(body)

  defp format_error(%{__exception__: true} = exception), do: Exception.message(exception)
  defp format_error(reason), do: inspect(reason)

  defp build_result_attrs({:up, status}, elapsed_ms, checked_at) do
    %{
      status: :up,
      status_code: status,
      response_ms: elapsed_ms,
      error: nil,
      checked_at: checked_at
    }
  end

  defp build_result_attrs({:down, status, error}, elapsed_ms, checked_at) do
    %{
      status: :down,
      status_code: status,
      response_ms: elapsed_ms,
      error: error,
      checked_at: checked_at
    }
  end

  defp apply_outcome(%Check{} = check, {:up, _status}, checked_at) do
    {:ok, updated} =
      Monitoring.update_runtime_fields(check, %{
        status: :up,
        consecutive_failures: 0,
        last_checked_at: checked_at
      })

    Monitoring.broadcast_check_run_completed(updated)
    updated
  end

  defp apply_outcome(%Check{} = check, {:down, _status, _error}, checked_at) do
    {:ok, updated} =
      Monitoring.update_runtime_fields(check, %{
        status: :down,
        consecutive_failures: check.consecutive_failures + 1,
        last_checked_at: checked_at
      })

    Monitoring.broadcast_check_run_completed(updated)
    updated
  end

  defp http_client do
    Application.get_env(:app, __MODULE__, [])
    |> Keyword.get(:http_client, FF.Monitoring.HttpClient.Req)
  end
end
