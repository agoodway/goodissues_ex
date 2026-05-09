defmodule FF.Monitoring.IncidentLifecycleTest do
  use FF.DataCase, async: false

  import FF.AccountsFixtures
  import FF.MonitoringFixtures
  import FF.TrackingFixtures

  alias FF.Monitoring
  alias FF.Monitoring.{Check, IncidentLifecycle}
  alias FF.Repo
  alias FF.Tracking.Issue

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  defp seed_failed_result(check, opts \\ []) do
    {:ok, result} =
      Monitoring.create_check_result(check, %{
        status: :down,
        status_code: Keyword.get(opts, :status_code, 500),
        response_ms: 10,
        error: Keyword.get(opts, :error, "boom")
      })

    result
  end

  describe "create_or_reopen_incident/3 — no prior incident" do
    test "creates a new incident issue with the bot user as submitter", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{name: "Health"})
      result = seed_failed_result(check, error: "connection refused")

      assert :ok = IncidentLifecycle.create_or_reopen_incident(account, check, result)

      [issue] = list_incident_issues(project.id)
      assert issue.title == "DOWN: Health"
      assert issue.type == :incident
      assert issue.priority == :critical
      assert issue.status == :new
      assert issue.description =~ "connection refused"

      reloaded = Repo.get(Check, check.id)
      assert reloaded.current_issue_id == issue.id
      assert reloaded.status == :down

      reloaded_result = Repo.get(FF.Monitoring.CheckResult, result.id)
      assert reloaded_result.issue_id == issue.id

      bot = FF.Accounts.get_or_create_bot_user!(account)
      assert issue.submitter_id == bot.id
    end
  end

  describe "create_or_reopen_incident/3 — open incident already exists" do
    test "no-ops if an open incident is already linked", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      issue = issue_fixture(account, user, project, %{type: :incident, status: :in_progress})

      {:ok, check} =
        Monitoring.update_runtime_fields(check, %{
          current_issue_id: issue.id,
          status: :down,
          consecutive_failures: 1
        })

      result = seed_failed_result(check)

      assert :ok = IncidentLifecycle.create_or_reopen_incident(account, check, result)

      assert length(list_incident_issues(project.id)) == 1
    end
  end

  describe "create_or_reopen_incident/3 — recent archived incident" do
    test "reopens an archived incident within the reopen window", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{reopen_window_hours: 24})

      archived =
        issue_fixture(account, user, project, %{type: :incident, status: :archived})

      {:ok, _} =
        Monitoring.create_check_result(check, %{
          status: :down,
          status_code: 500,
          response_ms: 5,
          issue_id: archived.id
        })

      result = seed_failed_result(check)

      assert :ok = IncidentLifecycle.create_or_reopen_incident(account, check, result)

      reopened = Repo.get(Issue, archived.id)
      assert reopened.status == :in_progress

      reloaded = Repo.get(Check, check.id)
      assert reloaded.current_issue_id == reopened.id

      assert length(list_incident_issues(project.id)) == 1
    end
  end

  describe "create_or_reopen_incident/3 — old archived incident" do
    test "creates a new incident when the latest archive is outside the window", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project, %{reopen_window_hours: 1})

      old_archived =
        issue_fixture(account, user, project, %{type: :incident, status: :archived})

      old_archived
      |> Ecto.Changeset.change(
        archived_at: DateTime.add(DateTime.utc_now(:second), -7200, :second)
      )
      |> Repo.update!()

      {:ok, _} =
        Monitoring.create_check_result(check, %{
          status: :down,
          status_code: 500,
          response_ms: 5,
          issue_id: old_archived.id
        })

      result = seed_failed_result(check)

      assert :ok = IncidentLifecycle.create_or_reopen_incident(account, check, result)

      assert length(list_incident_issues(project.id)) == 2
    end
  end

  describe "archive_incident/2" do
    test "archives the issue and clears the check's current_issue_id", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      issue = issue_fixture(account, user, project, %{type: :incident, status: :in_progress})

      {:ok, check} =
        Monitoring.update_runtime_fields(check, %{
          current_issue_id: issue.id,
          status: :down
        })

      assert :ok = IncidentLifecycle.archive_incident(check, issue)

      reloaded_issue = Repo.get(Issue, issue.id)
      assert reloaded_issue.status == :archived
      assert reloaded_issue.archived_at != nil

      reloaded_check = Repo.get(Check, check.id)
      assert reloaded_check.current_issue_id == nil
      assert reloaded_check.status == :up
    end
  end

  describe "handle_recovery/1" do
    test "archives the open incident when current_issue_id points to one", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      issue = issue_fixture(account, user, project, %{type: :incident, status: :new})

      {:ok, check} =
        Monitoring.update_runtime_fields(check, %{current_issue_id: issue.id, status: :down})

      assert :ok = IncidentLifecycle.handle_recovery(check)

      reloaded_issue = Repo.get(Issue, issue.id)
      assert reloaded_issue.status == :archived

      reloaded_check = Repo.get(Check, check.id)
      assert reloaded_check.current_issue_id == nil
    end

    test "is a no-op when there is no current incident", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      assert :ok = IncidentLifecycle.handle_recovery(check)
    end

    test "clears stale current_issue_id when issue is already archived (manual)", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      issue = issue_fixture(account, user, project, %{type: :incident, status: :archived})

      {:ok, check} =
        Monitoring.update_runtime_fields(check, %{current_issue_id: issue.id})

      assert :ok = IncidentLifecycle.handle_recovery(check)

      reloaded = Repo.get(Check, check.id)
      assert reloaded.current_issue_id == nil
    end
  end

  defp list_incident_issues(project_id) do
    import Ecto.Query

    from(i in Issue,
      where: i.project_id == ^project_id and i.type == :incident,
      order_by: [asc: i.inserted_at]
    )
    |> Repo.all()
  end
end
