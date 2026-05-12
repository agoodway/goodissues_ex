defmodule GI.Monitoring.IncidentLifecycleTest do
  use GI.DataCase, async: false

  import GI.AccountsFixtures
  import GI.MonitoringFixtures
  import GI.TrackingFixtures

  alias GI.Monitoring
  alias GI.Monitoring.{Check, IncidentLifecycle}
  alias GI.Repo
  alias GI.Tracking
  alias GI.Tracking.Issue

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

      reloaded = Repo.get(Check, check.id)
      assert reloaded.current_issue_id == issue.id
      assert reloaded.status == :down

      reloaded_result = Repo.get(GI.Monitoring.CheckResult, result.id)
      assert reloaded_result.issue_id == issue.id

      bot = GI.Accounts.get_or_create_bot_user!(account)
      assert issue.submitter_id == bot.id

      # Verify incident was created with metadata
      incident = Tracking.get_incident_by_fingerprint(account, "check_#{check.id}")
      assert incident != nil
      assert incident.title == "DOWN: Health"
      assert incident.severity == :critical
      assert incident.source == "monitoring"
    end
  end

  describe "create_or_reopen_incident/3 — open incident already exists" do
    test "adds occurrence if an open incident is already linked", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      result1 = seed_failed_result(check)

      # First call creates the incident
      assert :ok = IncidentLifecycle.create_or_reopen_incident(account, check, result1)

      # Reload the check to get current_issue_id
      check = Repo.get(Check, check.id)

      result2 = seed_failed_result(check)

      # Second call should add an occurrence (not create a new issue)
      assert :ok = IncidentLifecycle.create_or_reopen_incident(account, check, result2)

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
      result1 = seed_failed_result(check)

      # Create the initial incident
      assert :ok = IncidentLifecycle.create_or_reopen_incident(account, check, result1)

      check = Repo.get(Check, check.id)
      issue_id = check.current_issue_id

      # Archive it (simulate recovery)
      assert :ok = IncidentLifecycle.handle_recovery(check)

      # Verify it was archived
      archived = Repo.get(Issue, issue_id)
      assert archived.status == :archived

      check = Repo.get(Check, check.id)
      result2 = seed_failed_result(check)

      # Report again — should reopen
      assert :ok = IncidentLifecycle.create_or_reopen_incident(account, check, result2)

      reopened = Repo.get(Issue, issue_id)
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
      result1 = seed_failed_result(check)

      # Create the initial incident
      assert :ok = IncidentLifecycle.create_or_reopen_incident(account, check, result1)

      check = Repo.get(Check, check.id)
      issue_id = check.current_issue_id

      # Archive it
      assert :ok = IncidentLifecycle.handle_recovery(check)

      # Backdate the archived_at to be outside the reopen window
      archived = Repo.get(Issue, issue_id)

      archived
      |> Ecto.Changeset.change(
        archived_at: DateTime.add(DateTime.utc_now(:second), -7200, :second)
      )
      |> Repo.update!()

      check = Repo.get(Check, check.id)
      result2 = seed_failed_result(check)

      # Report again — should create a new issue since the old one is outside the window
      assert :ok = IncidentLifecycle.create_or_reopen_incident(account, check, result2)

      assert length(list_incident_issues(project.id)) == 2
    end
  end

  describe "handle_recovery/1" do
    test "resolves the incident when current_issue_id points to one", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      result = seed_failed_result(check)

      # Create incident first
      assert :ok = IncidentLifecycle.create_or_reopen_incident(account, check, result)

      check = Repo.get(Check, check.id)
      issue_id = check.current_issue_id
      assert issue_id != nil

      assert :ok = IncidentLifecycle.handle_recovery(check)

      reloaded_issue = Repo.get(Issue, issue_id)
      assert reloaded_issue.status == :archived

      reloaded_check = Repo.get(Check, check.id)
      assert reloaded_check.current_issue_id == nil

      # Verify incident is resolved
      incident = Tracking.get_incident_by_fingerprint(account, "check_#{check.id}")
      assert incident.status == :resolved
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

  describe "handle_recovery/1 — resolve_and_cleanup nil-incident branch" do
    test "clears check state when no incident exists for fingerprint", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      issue = issue_fixture(account, user, project, %{type: :incident, status: :new})

      # Set current_issue_id to an issue that has no corresponding incident
      {:ok, check} =
        Monitoring.update_runtime_fields(check, %{current_issue_id: issue.id, status: :down})

      # No incident exists for this check's fingerprint
      assert Tracking.get_incident_by_fingerprint(account, "check_#{check.id}") == nil

      assert :ok = IncidentLifecycle.handle_recovery(check)

      reloaded = Repo.get(Check, check.id)
      assert reloaded.current_issue_id == nil
      assert reloaded.status == :up
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
