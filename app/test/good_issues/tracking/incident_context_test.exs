defmodule GI.Tracking.IncidentContextTest do
  use GI.DataCase, async: false

  import GI.AccountsFixtures
  import GI.TrackingFixtures

  alias GI.Repo
  alias GI.Tracking
  alias GI.Tracking.{Incident, Issue}

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  # ===== report_incident/5 =====

  describe "report_incident/5 — new incident" do
    test "creates a new incident and issue", %{
      user: user,
      account: account,
      project: project
    } do
      attrs = valid_incident_attributes(%{fingerprint: "svc_timeout"})
      occ_attrs = valid_incident_occurrence_attributes()

      assert {:ok, incident, :created} =
               Tracking.report_incident(account, user, project.id, attrs, occ_attrs)

      assert incident.fingerprint == "svc_timeout"
      assert incident.title == attrs.title
      assert incident.severity == :warning
      assert incident.status == :unresolved
      assert incident.muted == false
      assert incident.account_id == account.id
      assert incident.issue_id != nil

      # Issue was created
      issue = Repo.get!(Issue, incident.issue_id)
      assert issue.type == :incident
      assert issue.status == :new

      # Occurrence was created
      occurrences = Repo.preload(incident, :incident_occurrences).incident_occurrences
      assert length(occurrences) == 1
    end

    test "returns error for non-existent project", %{user: user, account: account} do
      attrs = valid_incident_attributes()
      occ_attrs = valid_incident_occurrence_attributes()
      fake_id = Ecto.UUID.generate()

      assert {:error, :project_not_found} =
               Tracking.report_incident(account, user, fake_id, attrs, occ_attrs)
    end
  end

  describe "report_incident/5 — existing incident, open issue" do
    test "adds occurrence to existing incident", %{
      user: user,
      account: account,
      project: project
    } do
      fingerprint = unique_incident_fingerprint()
      attrs = valid_incident_attributes(%{fingerprint: fingerprint})
      occ_attrs = valid_incident_occurrence_attributes()

      {:ok, incident, :created} =
        Tracking.report_incident(account, user, project.id, attrs, occ_attrs)

      # Report again with same fingerprint
      {:ok, updated, :occurrence_added} =
        Tracking.report_incident(account, user, project.id, attrs, %{context: %{"retry" => true}})

      assert updated.id == incident.id
      occurrences = Repo.preload(updated, :incident_occurrences, force: true).incident_occurrences
      assert length(occurrences) == 2
    end
  end

  describe "report_incident/5 — recently archived issue (reopen)" do
    test "reopens incident within reopen window", %{
      user: user,
      account: account,
      project: project
    } do
      fingerprint = unique_incident_fingerprint()
      attrs = valid_incident_attributes(%{fingerprint: fingerprint})
      occ_attrs = valid_incident_occurrence_attributes()

      {:ok, incident, :created} =
        Tracking.report_incident(account, user, project.id, attrs, occ_attrs)

      # Resolve the incident
      {:ok, _} = Tracking.resolve_incident(incident)

      # Report again — should reopen
      {:ok, reopened, :reopened} =
        Tracking.report_incident(account, user, project.id, attrs, occ_attrs)

      assert reopened.id == incident.id
      assert reopened.status == :unresolved

      issue = Repo.get!(Issue, reopened.issue_id)
      assert issue.status == :in_progress
    end
  end

  describe "report_incident/5 — old archived issue (create new)" do
    test "creates new issue when archive is outside reopen window", %{
      user: user,
      account: account,
      project: project
    } do
      fingerprint = unique_incident_fingerprint()
      attrs = valid_incident_attributes(%{fingerprint: fingerprint, reopen_window_hours: 1})
      occ_attrs = valid_incident_occurrence_attributes()

      {:ok, incident, :created} =
        Tracking.report_incident(account, user, project.id, attrs, occ_attrs)

      old_issue_id = incident.issue_id

      # Resolve the incident
      {:ok, _} = Tracking.resolve_incident(incident)

      # Backdate the archived_at to be outside the window
      issue = Repo.get!(Issue, old_issue_id)

      issue
      |> Ecto.Changeset.change(
        archived_at: DateTime.add(DateTime.utc_now(:second), -7200, :second)
      )
      |> Repo.update!()

      # Report again — should create a new issue
      {:ok, new_incident, :new_issue} =
        Tracking.report_incident(account, user, project.id, attrs, occ_attrs)

      assert new_incident.id == incident.id
      assert new_incident.issue_id != old_issue_id
      assert new_incident.status == :unresolved
    end
  end

  # ===== resolve_incident/2 =====

  describe "resolve_incident/2" do
    test "resolves an open incident", %{user: user, account: account, project: project} do
      incident = incident_fixture(account, user, project)
      assert incident.status == :unresolved

      {:ok, resolved} = Tracking.resolve_incident(incident)
      assert resolved.status == :resolved

      issue = Repo.get!(Issue, resolved.issue_id)
      assert issue.status == :archived
    end

    test "no-ops for already-resolved incident", %{
      user: user,
      account: account,
      project: project
    } do
      incident = incident_fixture(account, user, project)
      {:ok, resolved} = Tracking.resolve_incident(incident)

      {:ok, same} = Tracking.resolve_incident(resolved)
      assert same.status == :resolved
    end
  end

  # ===== get/list/update =====

  describe "get_incident/3" do
    test "returns incident scoped to account", %{
      user: user,
      account: account,
      project: project
    } do
      incident = incident_fixture(account, user, project)
      found = Tracking.get_incident(account, incident.id)
      assert found.id == incident.id
    end

    test "returns nil for other account's incident", %{
      user: user,
      account: account,
      project: project
    } do
      incident = incident_fixture(account, user, project)
      {_other_user, other_account} = user_with_account_fixture()
      assert Tracking.get_incident(other_account, incident.id) == nil
    end

    test "returns nil for invalid UUID", %{account: account} do
      assert Tracking.get_incident(account, "not-a-uuid") == nil
    end
  end

  describe "get_incident_by_fingerprint/2" do
    test "finds incident by fingerprint within account", %{
      user: user,
      account: account,
      project: project
    } do
      fingerprint = unique_incident_fingerprint()
      _incident = incident_fixture(account, user, project, %{fingerprint: fingerprint})

      found = Tracking.get_incident_by_fingerprint(account, fingerprint)
      assert found != nil
      assert found.fingerprint == fingerprint
    end

    test "returns nil for non-existent fingerprint", %{account: account} do
      assert Tracking.get_incident_by_fingerprint(account, "nonexistent") == nil
    end
  end

  describe "list_incidents_paginated/2" do
    test "lists incidents for account with pagination", %{
      user: user,
      account: account,
      project: project
    } do
      _i1 = incident_fixture(account, user, project, %{fingerprint: "fp1"})
      _i2 = incident_fixture(account, user, project, %{fingerprint: "fp2"})

      result = Tracking.list_incidents_paginated(account)
      assert result.total == 2
      assert result.page == 1
      assert length(result.incidents) == 2
    end

    test "filters by status", %{user: user, account: account, project: project} do
      incident = incident_fixture(account, user, project)
      {:ok, _} = Tracking.resolve_incident(incident)

      result = Tracking.list_incidents_paginated(account, %{status: "resolved"})
      assert result.total == 1

      result = Tracking.list_incidents_paginated(account, %{status: "unresolved"})
      assert result.total == 0
    end

    test "filters by severity", %{user: user, account: account, project: project} do
      _i = incident_fixture(account, user, project, %{severity: :critical})

      result = Tracking.list_incidents_paginated(account, %{severity: "critical"})
      assert result.total == 1

      result = Tracking.list_incidents_paginated(account, %{severity: "info"})
      assert result.total == 0
    end

    test "filters by muted", %{user: user, account: account, project: project} do
      _i = incident_fixture(account, user, project)

      result = Tracking.list_incidents_paginated(account, %{muted: false})
      assert result.total == 1

      result = Tracking.list_incidents_paginated(account, %{muted: true})
      assert result.total == 0
    end

    test "filters by source", %{user: user, account: account, project: project} do
      _i = incident_fixture(account, user, project, %{source: "api-gateway"})

      result = Tracking.list_incidents_paginated(account, %{source: "api-gateway"})
      assert result.total == 1

      result = Tracking.list_incidents_paginated(account, %{source: "other"})
      assert result.total == 0
    end

    test "does not include incidents from other accounts", %{
      user: user,
      account: account,
      project: project
    } do
      _i = incident_fixture(account, user, project)
      {_other_user, other_account} = user_with_account_fixture()

      result = Tracking.list_incidents_paginated(other_account)
      assert result.total == 0
    end

    test "paginates correctly", %{user: user, account: account, project: project} do
      for i <- 1..5 do
        incident_fixture(account, user, project, %{fingerprint: "pg_#{i}"})
      end

      result = Tracking.list_incidents_paginated(account, %{page: 1, per_page: 2})
      assert length(result.incidents) == 2
      assert result.total == 5
      assert result.total_pages == 3

      result = Tracking.list_incidents_paginated(account, %{page: 3, per_page: 2})
      assert length(result.incidents) == 1
    end
  end

  describe "get_incident_with_occurrences/3" do
    test "returns incident with paginated occurrences", %{
      user: user,
      account: account,
      project: project
    } do
      fingerprint = unique_incident_fingerprint()
      attrs = valid_incident_attributes(%{fingerprint: fingerprint})
      occ = valid_incident_occurrence_attributes()

      {:ok, incident, :created} =
        Tracking.report_incident(account, user, project.id, attrs, occ)

      # Add more occurrences
      {:ok, _, :occurrence_added} =
        Tracking.report_incident(account, user, project.id, attrs, %{context: %{"n" => 2}})

      result = Tracking.get_incident_with_occurrences(account, incident.id)
      assert result.id == incident.id
      assert result.occurrence_count == 2
      assert length(result.incident_occurrences) == 2
    end

    test "returns nil for non-existent incident", %{account: account} do
      assert Tracking.get_incident_with_occurrences(account, Ecto.UUID.generate()) == nil
    end
  end

  describe "update_incident/2" do
    test "updates muted field", %{user: user, account: account, project: project} do
      incident = incident_fixture(account, user, project)
      {:ok, updated} = Tracking.update_incident(incident, %{muted: true})
      assert updated.muted == true
    end

    test "does not allow status updates", %{user: user, account: account, project: project} do
      incident = incident_fixture(account, user, project)
      {:ok, unchanged} = Tracking.update_incident(incident, %{status: :resolved})
      assert unchanged.status == :unresolved
    end
  end

  # ===== Advanced tests: isolation, concurrency, validation =====

  describe "account isolation" do
    test "fingerprint uniqueness is scoped to account", %{
      user: user,
      account: account,
      project: project
    } do
      fingerprint = "shared_fingerprint"
      attrs = valid_incident_attributes(%{fingerprint: fingerprint})
      occ = valid_incident_occurrence_attributes()

      {:ok, i1, :created} = Tracking.report_incident(account, user, project.id, attrs, occ)

      # Different account can use the same fingerprint
      {other_user, other_account} = user_with_account_fixture()
      other_project = project_fixture(other_account)

      {:ok, i2, :created} =
        Tracking.report_incident(other_account, other_user, other_project.id, attrs, occ)

      assert i1.id != i2.id
      assert i1.fingerprint == i2.fingerprint
    end
  end

  describe "advisory lock concurrency" do
    test "concurrent reports with same fingerprint don't create duplicates", %{
      user: user,
      account: account,
      project: project
    } do
      fingerprint = "concurrent_test"
      attrs = valid_incident_attributes(%{fingerprint: fingerprint})
      occ = valid_incident_occurrence_attributes()

      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            Tracking.report_incident(account, user, project.id, attrs, occ)
          end)
        end

      results = Task.await_many(tasks)

      created_count =
        Enum.count(results, fn
          {:ok, _, :created} -> true
          _ -> false
        end)

      added_count =
        Enum.count(results, fn
          {:ok, _, :occurrence_added} -> true
          _ -> false
        end)

      assert created_count == 1
      assert added_count == 4
    end
  end

  describe "validation edge cases" do
    test "rejects invalid severity string via Ecto.Enum", %{
      user: user,
      account: account,
      project: project
    } do
      attrs = valid_incident_attributes(%{severity: "invalid_severity"})
      occ = valid_incident_occurrence_attributes()

      assert {:error, _changeset} =
               Tracking.report_incident(account, user, project.id, attrs, occ)
    end

    test "rejects fingerprint longer than 255 chars", %{
      user: user,
      account: account,
      project: project
    } do
      attrs = valid_incident_attributes(%{fingerprint: String.duplicate("x", 256)})
      occ = valid_incident_occurrence_attributes()

      assert {:error, _changeset} =
               Tracking.report_incident(account, user, project.id, attrs, occ)
    end
  end
end
