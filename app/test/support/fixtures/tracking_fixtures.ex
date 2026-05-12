defmodule GI.TrackingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `GI.Tracking` context.
  """

  alias GI.Tracking

  def unique_project_name, do: "project#{System.unique_integer()}"
  def unique_issue_title, do: "issue#{System.unique_integer()}"
  def unique_project_prefix, do: "P#{:erlang.unique_integer([:positive]) |> rem(9999)}"

  def valid_project_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_project_name(),
      description: "A test project description",
      prefix: unique_project_prefix()
    })
  end

  @doc """
  Creates a project fixture.

  Requires an account to be passed in attrs.
  """
  def project_fixture(account, attrs \\ %{}) do
    {:ok, project} =
      attrs
      |> valid_project_attributes()
      |> then(&Tracking.create_project(account, &1))

    project
  end

  def valid_issue_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: unique_issue_title(),
      description: "A test issue description",
      type: :bug,
      status: :new,
      priority: :medium
    })
  end

  @doc """
  Creates an issue fixture.

  Requires an account, user, and project to be passed.
  """
  def issue_fixture(account, user, project, attrs \\ %{}) do
    {:ok, issue} =
      attrs
      |> valid_issue_attributes()
      |> Map.put(:project_id, project.id)
      |> then(&Tracking.create_issue(account, user, &1))

    issue
  end

  def unique_fingerprint, do: :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)

  def valid_error_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      kind: "Elixir.RuntimeError",
      reason: "something went wrong",
      source_line: "lib/app/worker.ex:42",
      source_function: "MyApp.Worker.perform/2",
      fingerprint: unique_fingerprint(),
      last_occurrence_at: DateTime.utc_now(:second)
    })
  end

  def valid_occurrence_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      reason: "something went wrong",
      context: %{"request_id" => "abc123"},
      breadcrumbs: ["Started processing", "Fetched data"],
      stacktrace_lines: [
        %{
          application: "my_app",
          module: "MyApp.Worker",
          function: "perform",
          arity: 2,
          file: "lib/my_app/worker.ex",
          line: 42
        },
        %{
          application: "elixir",
          module: "Task.Supervised",
          function: "invoke",
          arity: 2,
          file: "lib/task/supervised.ex",
          line: 90
        }
      ]
    })
  end

  @doc """
  Creates an error fixture with an occurrence.

  Requires an issue to be passed.
  """
  def error_fixture(issue, error_attrs \\ %{}, occurrence_attrs \\ %{}) do
    {:ok, error} =
      Tracking.create_error_with_occurrence(
        issue,
        valid_error_attributes(error_attrs),
        valid_occurrence_attributes(occurrence_attrs)
      )

    error
  end

  def unique_incident_fingerprint, do: "incident_#{System.unique_integer([:positive])}"

  def valid_incident_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      fingerprint: unique_incident_fingerprint(),
      title: "Test Incident #{System.unique_integer([:positive])}",
      severity: :warning,
      source: "test-service",
      metadata: %{"region" => "us-east-1"}
    })
  end

  def valid_incident_occurrence_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      context: %{"request_id" => "req_#{System.unique_integer([:positive])}"}
    })
  end

  @doc """
  Creates an incident fixture via report_incident/5.

  Requires account, user, and project.
  """
  def incident_fixture(account, user, project, incident_attrs \\ %{}, occurrence_attrs \\ %{}) do
    {:ok, incident, _status} =
      Tracking.report_incident(
        account,
        user,
        project.id,
        valid_incident_attributes(incident_attrs),
        valid_incident_occurrence_attributes(occurrence_attrs)
      )

    incident
  end
end
