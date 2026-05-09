defmodule GI.TrackingTest do
  use GI.DataCase

  alias GI.Tracking
  alias GI.Tracking.{Error, Issue, Occurrence, Project}

  import GI.AccountsFixtures
  import GI.TrackingFixtures

  describe "list_projects/1" do
    test "returns all projects for the account" do
      {_user, account} = user_with_account_fixture()
      project1 = project_fixture(account, %{name: "Alpha"})
      project2 = project_fixture(account, %{name: "Beta"})

      projects = Tracking.list_projects(account)

      assert length(projects) == 2
      assert Enum.map(projects, & &1.id) == [project1.id, project2.id]
    end

    test "returns projects ordered by name" do
      {_user, account} = user_with_account_fixture()
      _project_z = project_fixture(account, %{name: "Zebra"})
      _project_a = project_fixture(account, %{name: "Apple"})

      [first, second] = Tracking.list_projects(account)

      assert first.name == "Apple"
      assert second.name == "Zebra"
    end

    test "does not return projects from other accounts" do
      {_user1, account1} = user_with_account_fixture()
      {_user2, account2} = user_with_account_fixture()
      project1 = project_fixture(account1)
      _project2 = project_fixture(account2)

      projects = Tracking.list_projects(account1)

      assert length(projects) == 1
      assert hd(projects).id == project1.id
    end

    test "returns empty list when no projects exist" do
      {_user, account} = user_with_account_fixture()

      assert Tracking.list_projects(account) == []
    end
  end

  describe "get_project/2" do
    test "returns project when it belongs to the account" do
      {_user, account} = user_with_account_fixture()
      project = project_fixture(account)

      assert Tracking.get_project(account, project.id) == project
    end

    test "returns nil when project belongs to different account" do
      {_user1, account1} = user_with_account_fixture()
      {_user2, account2} = user_with_account_fixture()
      project = project_fixture(account2)

      assert Tracking.get_project(account1, project.id) == nil
    end

    test "returns nil for non-existent project" do
      {_user, account} = user_with_account_fixture()

      assert Tracking.get_project(account, Ecto.UUID.generate()) == nil
    end
  end

  describe "create_project/2" do
    test "creates project with valid attributes" do
      {_user, account} = user_with_account_fixture()

      assert {:ok, %Project{} = project} =
               Tracking.create_project(account, %{
                 name: "My Project",
                 description: "A description",
                 prefix: "MP"
               })

      assert project.name == "My Project"
      assert project.description == "A description"
      assert project.prefix == "MP"
      assert project.issue_counter == 1
      assert project.account_id == account.id
    end

    test "returns error changeset with invalid attributes" do
      {_user, account} = user_with_account_fixture()

      assert {:error, %Ecto.Changeset{}} = Tracking.create_project(account, %{name: nil})
    end

    test "creates project without description" do
      {_user, account} = user_with_account_fixture()

      assert {:ok, %Project{} = project} =
               Tracking.create_project(account, %{name: "My Project", prefix: "MP"})

      assert project.description == nil
    end

    test "validates prefix format" do
      {_user, account} = user_with_account_fixture()

      # lowercase is normalized to uppercase
      assert {:ok, project} =
               Tracking.create_project(account, %{name: "Test", prefix: "test"})

      assert project.prefix == "TEST"

      # invalid characters
      assert {:error, changeset} =
               Tracking.create_project(account, %{name: "Test2", prefix: "TE-ST"})

      assert "must be uppercase letters and numbers only" in errors_on(changeset).prefix
    end

    test "validates prefix length" do
      {_user, account} = user_with_account_fixture()

      # too long
      assert {:error, changeset} =
               Tracking.create_project(account, %{name: "Test", prefix: "TOOLONGPREFIX"})

      assert "should be at most 10 character(s)" in errors_on(changeset).prefix
    end

    test "validates prefix uniqueness within account" do
      {_user, account} = user_with_account_fixture()

      {:ok, _project1} =
        Tracking.create_project(account, %{name: "Project 1", prefix: "PRJ"})

      assert {:error, changeset} =
               Tracking.create_project(account, %{name: "Project 2", prefix: "PRJ"})

      assert "already exists in this account" in errors_on(changeset).prefix
    end
  end

  describe "update_project/2" do
    test "updates project with valid attributes" do
      {_user, account} = user_with_account_fixture()
      project = project_fixture(account)

      assert {:ok, %Project{} = updated} =
               Tracking.update_project(project, %{
                 name: "Updated Name",
                 description: "New description"
               })

      assert updated.name == "Updated Name"
      assert updated.description == "New description"
    end

    test "returns error changeset with invalid attributes" do
      {_user, account} = user_with_account_fixture()
      project = project_fixture(account)

      assert {:error, %Ecto.Changeset{}} =
               Tracking.update_project(project, %{name: String.duplicate("a", 256)})
    end

    test "allows partial updates without name" do
      {_user, account} = user_with_account_fixture()
      project = project_fixture(account, %{name: "Original"})

      assert {:ok, updated} = Tracking.update_project(project, %{description: "New description"})
      assert updated.name == "Original"
      assert updated.description == "New description"
    end
  end

  describe "delete_project/1" do
    test "deletes the project" do
      {_user, account} = user_with_account_fixture()
      project = project_fixture(account)

      assert {:ok, %Project{}} = Tracking.delete_project(project)
      assert Tracking.get_project(account, project.id) == nil
    end
  end

  # ==========================================================================
  # Issues
  # ==========================================================================

  describe "list_issues/2" do
    test "returns all issues for the account" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue1 = issue_fixture(account, user, project)
      issue2 = issue_fixture(account, user, project)

      issues = Tracking.list_issues(account)

      assert length(issues) == 2
      assert Enum.map(issues, & &1.id) |> Enum.sort() == Enum.sort([issue1.id, issue2.id])
    end

    test "returns issues ordered by inserted_at descending" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue1 = issue_fixture(account, user, project)
      issue2 = issue_fixture(account, user, project)

      issues = Tracking.list_issues(account)

      # Verify ordering is by inserted_at desc (newer first)
      assert length(issues) == 2
      [first, second] = issues
      assert DateTime.compare(first.inserted_at, second.inserted_at) in [:gt, :eq]
      assert Enum.sort([issue1.id, issue2.id]) == Enum.sort([first.id, second.id])
    end

    test "does not return issues from other accounts" do
      {user1, account1} = user_with_account_fixture()
      {user2, account2} = user_with_account_fixture()
      project1 = project_fixture(account1)
      project2 = project_fixture(account2)
      issue1 = issue_fixture(account1, user1, project1)
      _issue2 = issue_fixture(account2, user2, project2)

      issues = Tracking.list_issues(account1)

      assert length(issues) == 1
      assert hd(issues).id == issue1.id
    end

    test "returns empty list when no issues exist" do
      {_user, account} = user_with_account_fixture()

      assert Tracking.list_issues(account) == []
    end

    test "filters by project_id" do
      {user, account} = user_with_account_fixture()
      project1 = project_fixture(account)
      project2 = project_fixture(account)
      issue1 = issue_fixture(account, user, project1)
      _issue2 = issue_fixture(account, user, project2)

      issues = Tracking.list_issues(account, %{project_id: project1.id})

      assert length(issues) == 1
      assert hd(issues).id == issue1.id
    end

    test "filters by status" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue_new = issue_fixture(account, user, project, %{status: :new})
      _issue_in_progress = issue_fixture(account, user, project, %{status: :in_progress})

      issues = Tracking.list_issues(account, %{status: :new})

      assert length(issues) == 1
      assert hd(issues).id == issue_new.id
    end

    test "filters by type" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue_bug = issue_fixture(account, user, project, %{type: :bug})
      _issue_feature = issue_fixture(account, user, project, %{type: :feature_request})

      issues = Tracking.list_issues(account, %{type: :bug})

      assert length(issues) == 1
      assert hd(issues).id == issue_bug.id
    end

    test "filters by incident type" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      incident_issue = issue_fixture(account, user, project, %{type: :incident})
      _issue_bug = issue_fixture(account, user, project, %{type: :bug})

      issues = Tracking.list_issues(account, %{type: :incident})

      assert length(issues) == 1
      assert hd(issues).id == incident_issue.id
    end

    test "filters by multiple criteria" do
      {user, account} = user_with_account_fixture()
      project1 = project_fixture(account)
      project2 = project_fixture(account)
      issue_match = issue_fixture(account, user, project1, %{type: :bug, status: :new})
      _issue_wrong_project = issue_fixture(account, user, project2, %{type: :bug, status: :new})

      _issue_wrong_type =
        issue_fixture(account, user, project1, %{type: :feature_request, status: :new})

      _issue_wrong_status =
        issue_fixture(account, user, project1, %{type: :bug, status: :in_progress})

      issues = Tracking.list_issues(account, %{project_id: project1.id, type: :bug, status: :new})

      assert length(issues) == 1
      assert hd(issues).id == issue_match.id
    end
  end

  describe "get_issue/2" do
    test "returns issue when it belongs to the account" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      result = Tracking.get_issue(account, issue.id)
      assert result.id == issue.id
      assert result.title == issue.title
    end

    test "returns nil when issue belongs to different account" do
      {_user1, account1} = user_with_account_fixture()
      {user2, account2} = user_with_account_fixture()
      project = project_fixture(account2)
      issue = issue_fixture(account2, user2, project)

      assert Tracking.get_issue(account1, issue.id) == nil
    end

    test "returns nil for non-existent issue" do
      {_user, account} = user_with_account_fixture()

      assert Tracking.get_issue(account, Ecto.UUID.generate()) == nil
    end
  end

  describe "create_issue/3" do
    test "creates issue with valid attributes" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)

      assert {:ok, %Issue{} = issue} =
               Tracking.create_issue(account, user, %{
                 title: "Bug report",
                 description: "Something is broken",
                 type: :bug,
                 project_id: project.id
               })

      assert issue.title == "Bug report"
      assert issue.description == "Something is broken"
      assert issue.type == :bug
      assert issue.status == :new
      assert issue.priority == :medium
      assert issue.project_id == project.id
      assert issue.submitter_id == user.id
    end

    test "returns error changeset with invalid attributes" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)

      assert {:error, %Ecto.Changeset{}} =
               Tracking.create_issue(account, user, %{project_id: project.id})
    end

    test "creates issue without description" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)

      assert {:ok, %Issue{} = issue} =
               Tracking.create_issue(account, user, %{
                 title: "Bug",
                 type: :bug,
                 project_id: project.id
               })

      assert issue.description == nil
    end

    test "returns error when project does not exist" do
      {user, account} = user_with_account_fixture()

      assert {:error, changeset} =
               Tracking.create_issue(account, user, %{
                 title: "Bug",
                 type: :bug,
                 project_id: Ecto.UUID.generate()
               })

      assert %{project_id: ["does not exist or belongs to another account"]} =
               errors_on(changeset)
    end

    test "returns error when project belongs to different account" do
      {user1, account1} = user_with_account_fixture()
      {_user2, account2} = user_with_account_fixture()
      project = project_fixture(account2)

      assert {:error, changeset} =
               Tracking.create_issue(account1, user1, %{
                 title: "Bug",
                 type: :bug,
                 project_id: project.id
               })

      assert %{project_id: ["does not exist or belongs to another account"]} =
               errors_on(changeset)
    end

    test "creates issue with submitter_email" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)

      assert {:ok, %Issue{} = issue} =
               Tracking.create_issue(account, user, %{
                 title: "Bug",
                 type: :bug,
                 project_id: project.id,
                 submitter_email: "external@example.com"
               })

      assert issue.submitter_email == "external@example.com"
    end

    test "sets archived_at when creating with archived status" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)

      assert {:ok, %Issue{} = issue} =
               Tracking.create_issue(account, user, %{
                 title: "Bug",
                 type: :bug,
                 status: :archived,
                 project_id: project.id
               })

      assert issue.status == :archived
      assert issue.archived_at != nil
    end

    test "assigns sequential issue numbers within a project" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)

      {:ok, issue1} =
        Tracking.create_issue(account, user, %{
          title: "First Issue",
          type: :bug,
          project_id: project.id
        })

      {:ok, issue2} =
        Tracking.create_issue(account, user, %{
          title: "Second Issue",
          type: :bug,
          project_id: project.id
        })

      {:ok, issue3} =
        Tracking.create_issue(account, user, %{
          title: "Third Issue",
          type: :bug,
          project_id: project.id
        })

      assert issue1.number == 1
      assert issue2.number == 2
      assert issue3.number == 3
    end

    test "assigns independent issue numbers per project" do
      {user, account} = user_with_account_fixture()
      project1 = project_fixture(account)
      project2 = project_fixture(account)

      {:ok, issue1_p1} =
        Tracking.create_issue(account, user, %{
          title: "Project 1 Issue 1",
          type: :bug,
          project_id: project1.id
        })

      {:ok, issue1_p2} =
        Tracking.create_issue(account, user, %{
          title: "Project 2 Issue 1",
          type: :bug,
          project_id: project2.id
        })

      {:ok, issue2_p1} =
        Tracking.create_issue(account, user, %{
          title: "Project 1 Issue 2",
          type: :bug,
          project_id: project1.id
        })

      # Each project has its own numbering sequence
      assert issue1_p1.number == 1
      assert issue1_p2.number == 1
      assert issue2_p1.number == 2
    end

    test "increments project counter when creating issues" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)

      # Initial counter should be 1
      assert project.issue_counter == 1

      {:ok, _issue1} =
        Tracking.create_issue(account, user, %{
          title: "Issue 1",
          type: :bug,
          project_id: project.id
        })

      # Reload project to get updated counter
      updated_project = Tracking.get_project(account, project.id)
      assert updated_project.issue_counter == 2

      {:ok, _issue2} =
        Tracking.create_issue(account, user, %{
          title: "Issue 2",
          type: :bug,
          project_id: project.id
        })

      updated_project = Tracking.get_project(account, project.id)
      assert updated_project.issue_counter == 3
    end
  end

  describe "update_issue/2" do
    test "updates issue with valid attributes" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      assert {:ok, %Issue{} = updated} =
               Tracking.update_issue(issue, %{
                 title: "Updated Title",
                 description: "New description"
               })

      assert updated.title == "Updated Title"
      assert updated.description == "New description"
    end

    test "returns error changeset with invalid attributes" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      assert {:error, %Ecto.Changeset{}} =
               Tracking.update_issue(issue, %{title: String.duplicate("a", 256)})
    end

    test "allows partial updates" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Original"})

      assert {:ok, updated} = Tracking.update_issue(issue, %{description: "New description"})
      assert updated.title == "Original"
      assert updated.description == "New description"
    end

    test "sets archived_at when status changes to archived" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{status: :new})

      assert {:ok, updated} = Tracking.update_issue(issue, %{status: :archived})
      assert updated.status == :archived
      assert updated.archived_at != nil
    end

    test "clears archived_at when status changes from archived" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{status: :archived})

      # Issue should have archived_at set
      assert issue.archived_at != nil

      assert {:ok, updated} = Tracking.update_issue(issue, %{status: :in_progress})
      assert updated.status == :in_progress
      assert updated.archived_at == nil
    end

    test "can update status to in_progress" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{status: :new})

      assert {:ok, updated} = Tracking.update_issue(issue, %{status: :in_progress})
      assert updated.status == :in_progress
    end

    test "can update priority" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{priority: :low})

      assert {:ok, updated} = Tracking.update_issue(issue, %{priority: :critical})
      assert updated.priority == :critical
    end

    test "can update type" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{type: :bug})

      assert {:ok, updated} = Tracking.update_issue(issue, %{type: :feature_request})
      assert updated.type == :feature_request
    end
  end

  describe "delete_issue/1" do
    test "deletes the issue" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      assert {:ok, %Issue{}} = Tracking.delete_issue(issue)
      assert Tracking.get_issue(account, issue.id) == nil
    end
  end

  # ==========================================================================
  # PubSub Broadcasting
  # ==========================================================================

  describe "create_issue/3 broadcasts" do
    test "broadcasts :issue_created event on successful issue creation" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)

      # Subscribe to the account's issues topic
      Phoenix.PubSub.subscribe(GI.PubSub, Tracking.issues_topic(account.id))

      {:ok, issue} =
        Tracking.create_issue(account, user, %{
          title: "Test Issue",
          type: :bug,
          project_id: project.id
        })

      assert_receive {:issue_created, payload}
      assert payload.id == issue.id
      assert payload.title == "Test Issue"
      assert payload.type == :bug
      assert payload.status == :new
      assert payload.project.id == project.id
      assert payload.project.prefix == project.prefix
    end

    test "does not broadcast on failed issue creation" do
      {user, account} = user_with_account_fixture()

      # Subscribe to the account's issues topic
      Phoenix.PubSub.subscribe(GI.PubSub, Tracking.issues_topic(account.id))

      # Try to create an issue with invalid project_id
      {:error, _changeset} =
        Tracking.create_issue(account, user, %{
          title: "Test Issue",
          type: :bug,
          project_id: Ecto.UUID.generate()
        })

      refute_receive {:issue_created, _}
    end
  end

  describe "update_issue/2 broadcasts" do
    test "broadcasts :issue_updated event on successful issue update" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      # Subscribe to the account's issues topic
      Phoenix.PubSub.subscribe(GI.PubSub, Tracking.issues_topic(account.id))

      {:ok, updated} =
        Tracking.update_issue(issue, %{title: "Updated Title", status: :in_progress})

      assert_receive {:issue_updated, payload}
      assert payload.id == updated.id
      assert payload.title == "Updated Title"
      assert payload.status == :in_progress
      assert payload.project.id == project.id
    end

    test "does not broadcast on failed issue update" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      # Subscribe to the account's issues topic
      Phoenix.PubSub.subscribe(GI.PubSub, Tracking.issues_topic(account.id))

      # Try to update with invalid title (too long)
      {:error, _changeset} = Tracking.update_issue(issue, %{title: String.duplicate("a", 256)})

      refute_receive {:issue_updated, _}
    end
  end

  describe "issues_topic/1" do
    test "returns the correct topic format" do
      account_id = Ecto.UUID.generate()
      assert Tracking.issues_topic(account_id) == "issues:account:#{account_id}"
    end
  end

  # ==========================================================================
  # Errors
  # ==========================================================================

  describe "get_error_by_fingerprint/2" do
    test "returns error when fingerprint exists in account" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue, %{fingerprint: "a" |> String.duplicate(64)})

      result = Tracking.get_error_by_fingerprint(account, "a" |> String.duplicate(64))
      assert result.id == error.id
    end

    test "returns nil when fingerprint does not exist" do
      {_user, account} = user_with_account_fixture()

      assert Tracking.get_error_by_fingerprint(
               account,
               "nonexistent" |> String.pad_trailing(64, "0")
             ) == nil
    end

    test "returns nil when fingerprint belongs to different account" do
      {user1, account1} = user_with_account_fixture()
      {_user2, account2} = user_with_account_fixture()
      project = project_fixture(account1)
      issue = issue_fixture(account1, user1, project)
      fingerprint = "b" |> String.duplicate(64)
      _error = error_fixture(issue, %{fingerprint: fingerprint})

      assert Tracking.get_error_by_fingerprint(account2, fingerprint) == nil
    end
  end

  describe "get_error/3" do
    test "returns error when it belongs to account" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      result = Tracking.get_error(account, error.id)
      assert result.id == error.id
    end

    test "returns nil when error belongs to different account" do
      {user1, account1} = user_with_account_fixture()
      {_user2, account2} = user_with_account_fixture()
      project = project_fixture(account1)
      issue = issue_fixture(account1, user1, project)
      error = error_fixture(issue)

      assert Tracking.get_error(account2, error.id) == nil
    end

    test "returns nil for non-existent error" do
      {_user, account} = user_with_account_fixture()

      assert Tracking.get_error(account, Ecto.UUID.generate()) == nil
    end
  end

  describe "list_errors/2" do
    test "returns all errors for the account" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue1 = issue_fixture(account, user, project)
      issue2 = issue_fixture(account, user, project)
      error1 = error_fixture(issue1)
      error2 = error_fixture(issue2)

      errors = Tracking.list_errors(account)

      assert length(errors) == 2
      assert Enum.map(errors, & &1.id) |> Enum.sort() == Enum.sort([error1.id, error2.id])
    end

    test "filters by status" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue1 = issue_fixture(account, user, project)
      issue2 = issue_fixture(account, user, project)
      _error_unresolved = error_fixture(issue1, %{})
      error_resolved = error_fixture(issue2, %{})
      {:ok, _} = Tracking.update_error(error_resolved, %{status: :resolved})

      errors = Tracking.list_errors(account, %{status: :resolved})

      assert length(errors) == 1
      assert hd(errors).status == :resolved
    end

    test "filters by muted" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue1 = issue_fixture(account, user, project)
      issue2 = issue_fixture(account, user, project)
      _error_unmuted = error_fixture(issue1, %{muted: false})
      error_muted = error_fixture(issue2, %{muted: true})

      errors = Tracking.list_errors(account, %{muted: true})

      assert length(errors) == 1
      assert hd(errors).id == error_muted.id
    end

    test "does not return errors from other accounts" do
      {user1, account1} = user_with_account_fixture()
      {user2, account2} = user_with_account_fixture()
      project1 = project_fixture(account1)
      project2 = project_fixture(account2)
      issue1 = issue_fixture(account1, user1, project1)
      issue2 = issue_fixture(account2, user2, project2)
      error1 = error_fixture(issue1)
      _error2 = error_fixture(issue2)

      errors = Tracking.list_errors(account1)

      assert length(errors) == 1
      assert hd(errors).id == error1.id
    end
  end

  describe "create_error_with_occurrence/3" do
    test "creates error with occurrence and stacktrace lines" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      error_attrs = %{
        kind: "Elixir.RuntimeError",
        reason: "test error",
        fingerprint: "c" |> String.duplicate(64),
        last_occurrence_at: DateTime.utc_now(:second)
      }

      occurrence_attrs = %{
        reason: "test error",
        context: %{"key" => "value"},
        breadcrumbs: ["step1", "step2"],
        stacktrace_lines: [
          %{module: "MyApp.Test", function: "run", arity: 1, file: "test.ex", line: 10}
        ]
      }

      assert {:ok, %Error{} = error} =
               Tracking.create_error_with_occurrence(issue, error_attrs, occurrence_attrs)

      assert error.kind == "Elixir.RuntimeError"
      assert error.issue_id == issue.id
      assert length(error.occurrences) == 1

      [occurrence] = error.occurrences
      assert occurrence.context == %{"key" => "value"}
      assert occurrence.breadcrumbs == ["step1", "step2"]
      assert length(occurrence.stacktrace_lines) == 1

      [line] = occurrence.stacktrace_lines
      assert line.module == "MyApp.Test"
      assert line.function == "run"
      assert line.position == 0
    end

    test "returns error when issue already has an error" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      _existing_error = error_fixture(issue)

      error_attrs = %{
        kind: "Elixir.RuntimeError",
        reason: "second error",
        fingerprint: "d" |> String.duplicate(64),
        last_occurrence_at: DateTime.utc_now(:second)
      }

      assert {:error, changeset} =
               Tracking.create_error_with_occurrence(issue, error_attrs, %{})

      assert "has already been taken" in errors_on(changeset).issue_id
    end
  end

  describe "add_occurrence/2" do
    test "adds occurrence to existing error and updates last_occurrence_at" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      # Create error with a past timestamp
      past_time = DateTime.utc_now(:second) |> DateTime.add(-60, :second)
      error = error_fixture(issue, %{last_occurrence_at: past_time})

      occurrence_attrs = %{
        reason: "new occurrence",
        context: %{"new" => "context"},
        breadcrumbs: ["new step"],
        stacktrace_lines: [
          %{module: "NewModule", function: "new_func", arity: 0, file: "new.ex", line: 1}
        ]
      }

      assert {:ok, %Occurrence{} = occurrence} = Tracking.add_occurrence(error, occurrence_attrs)

      assert occurrence.error_id == error.id
      assert occurrence.reason == "new occurrence"
      assert length(occurrence.stacktrace_lines) == 1

      # Check that error's last_occurrence_at was updated to a more recent time
      updated_error = Tracking.get_error(account, error.id)
      assert DateTime.compare(updated_error.last_occurrence_at, past_time) == :gt
    end
  end

  describe "report_error/5" do
    test "creates new issue and error when fingerprint is new" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      fingerprint = "e" |> String.duplicate(64)

      error_attrs = %{
        kind: "Elixir.RuntimeError",
        reason: "new error",
        fingerprint: fingerprint,
        last_occurrence_at: DateTime.utc_now(:second)
      }

      occurrence_attrs = %{
        reason: "new error",
        stacktrace_lines: [%{module: "Test", function: "run", arity: 0}]
      }

      assert {:ok, %Error{} = error, :created} =
               Tracking.report_error(account, user, project.id, error_attrs, occurrence_attrs)

      assert error.fingerprint == fingerprint
      assert error.issue.title == "Elixir.RuntimeError"
      assert error.issue.type == :bug
    end

    test "adds occurrence when fingerprint already exists" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      fingerprint = "f" |> String.duplicate(64)

      # First report creates the error
      error_attrs = %{
        kind: "Elixir.RuntimeError",
        reason: "original error",
        fingerprint: fingerprint,
        last_occurrence_at: DateTime.utc_now(:second)
      }

      {:ok, original_error, :created} =
        Tracking.report_error(account, user, project.id, error_attrs, %{})

      # Second report with same fingerprint adds occurrence
      {:ok, updated_error, :occurrence_added} =
        Tracking.report_error(account, user, project.id, error_attrs, %{reason: "new occurrence"})

      assert updated_error.id == original_error.id
      assert length(updated_error.occurrences) == 2
    end

    test "fingerprint is scoped to account" do
      {user1, account1} = user_with_account_fixture()
      {user2, account2} = user_with_account_fixture()
      project1 = project_fixture(account1)
      project2 = project_fixture(account2)
      fingerprint = "g" |> String.duplicate(64)

      error_attrs = %{
        kind: "Elixir.RuntimeError",
        reason: "error",
        fingerprint: fingerprint,
        last_occurrence_at: DateTime.utc_now(:second)
      }

      # First account creates error
      {:ok, error1, :created} =
        Tracking.report_error(account1, user1, project1.id, error_attrs, %{})

      # Second account with same fingerprint creates separate error
      {:ok, error2, :created} =
        Tracking.report_error(account2, user2, project2.id, error_attrs, %{})

      assert error1.id != error2.id
    end
  end

  describe "update_error/2" do
    test "updates error status" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      assert {:ok, %Error{} = updated} = Tracking.update_error(error, %{status: :resolved})
      assert updated.status == :resolved
    end

    test "updates error muted flag" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue, %{muted: false})

      assert {:ok, %Error{} = updated} = Tracking.update_error(error, %{muted: true})
      assert updated.muted == true
    end
  end

  describe "get_error_with_occurrences/3" do
    test "returns error with paginated occurrences" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      # Add more occurrences
      Tracking.add_occurrence(error, %{reason: "occurrence 2", stacktrace_lines: []})
      Tracking.add_occurrence(error, %{reason: "occurrence 3", stacktrace_lines: []})

      result = Tracking.get_error_with_occurrences(account, error.id, per_page: 2)

      assert result.id == error.id
      assert length(result.occurrences) == 2
      assert result.occurrence_count == 3
    end

    test "returns nil when error not found" do
      {_user, account} = user_with_account_fixture()

      assert Tracking.get_error_with_occurrences(account, Ecto.UUID.generate()) == nil
    end
  end

  describe "search_errors_by_stacktrace/2" do
    test "finds errors by module name" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue1 = issue_fixture(account, user, project)
      issue2 = issue_fixture(account, user, project)

      _error1 =
        error_fixture(issue1, %{}, %{
          stacktrace_lines: [%{module: "MyApp.Worker", function: "run", arity: 0}]
        })

      _error2 =
        error_fixture(issue2, %{}, %{
          stacktrace_lines: [%{module: "OtherApp.Handler", function: "handle", arity: 1}]
        })

      result = Tracking.search_errors_by_stacktrace(account, %{module: "MyApp.Worker"})

      assert length(result.errors) == 1
      assert result.page == 1
      assert result.per_page == 20
      assert result.total == 1
      assert result.total_pages == 1
    end

    test "finds errors by function name" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      _error =
        error_fixture(issue, %{}, %{
          stacktrace_lines: [%{module: "MyApp.Worker", function: "perform", arity: 2}]
        })

      result = Tracking.search_errors_by_stacktrace(account, %{function: "perform"})

      assert length(result.errors) == 1
    end

    test "finds errors by file path" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      _error =
        error_fixture(issue, %{}, %{
          stacktrace_lines: [
            %{module: "MyApp.Worker", function: "run", arity: 0, file: "lib/my_app/worker.ex"}
          ]
        })

      result = Tracking.search_errors_by_stacktrace(account, %{file: "lib/my_app/worker.ex"})

      assert length(result.errors) == 1
    end

    test "returns distinct errors when multiple occurrences match" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      error =
        error_fixture(issue, %{}, %{
          stacktrace_lines: [%{module: "SharedModule", function: "run", arity: 0}]
        })

      # Add another occurrence with same module
      Tracking.add_occurrence(error, %{
        stacktrace_lines: [%{module: "SharedModule", function: "other", arity: 1}]
      })

      result = Tracking.search_errors_by_stacktrace(account, %{module: "SharedModule"})

      # Should return just one error, not duplicates
      assert length(result.errors) == 1
      assert hd(result.errors).id == error.id
    end
  end

  describe "cascade deletion" do
    test "deleting issue deletes associated error" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      {:ok, _} = Tracking.delete_issue(issue)

      assert Tracking.get_error(account, error.id) == nil
    end
  end

  describe "get_error_summary/1" do
    test "returns error with occurrence count" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      # Add more occurrences
      Tracking.add_occurrence(error, %{reason: "second", stacktrace_lines: []})
      Tracking.add_occurrence(error, %{reason: "third", stacktrace_lines: []})

      result = Tracking.get_error_summary(error.id)

      assert result.id == error.id
      assert result.occurrence_count == 3
      assert result.issue != nil
    end

    test "returns nil for non-existent error" do
      assert Tracking.get_error_summary(Ecto.UUID.generate()) == nil
    end

    test "returns nil for nil input" do
      assert Tracking.get_error_summary(nil) == nil
    end

    test "returns nil for invalid uuid" do
      assert Tracking.get_error_summary("invalid") == nil
    end

    test "preloads occurrences with stacktrace lines" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      error =
        error_fixture(issue, %{}, %{
          stacktrace_lines: [
            %{module: "Test.Module", function: "run", arity: 0, file: "test.ex", line: 10}
          ]
        })

      result = Tracking.get_error_summary(error.id)

      assert length(result.occurrences) == 1
      [occurrence] = result.occurrences
      assert length(occurrence.stacktrace_lines) == 1
      assert hd(occurrence.stacktrace_lines).module == "Test.Module"
    end
  end

  describe "get_issue/3 with preload_error_with_count" do
    test "preloads error with occurrence count when option is true" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      # Add more occurrences
      Tracking.add_occurrence(error, %{reason: "second", stacktrace_lines: []})

      result = Tracking.get_issue(account, issue.id, preload_error_with_count: true)

      assert result.id == issue.id
      assert result.error != nil
      assert result.error.id == error.id
      assert result.error.occurrence_count == 2
    end

    test "sets error to nil when issue has no error" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      result = Tracking.get_issue(account, issue.id, preload_error_with_count: true)

      assert result.id == issue.id
      assert result.error == nil
    end

    test "preloads only one occurrence with stacktrace" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      error =
        error_fixture(issue, %{}, %{
          reason: "first",
          stacktrace_lines: [
            %{module: "Test.Module", function: "run", arity: 0, file: "test.ex", line: 10}
          ]
        })

      # Add more occurrences
      Tracking.add_occurrence(error, %{
        reason: "second",
        stacktrace_lines: [
          %{module: "Another.Module", function: "execute", arity: 1}
        ]
      })

      Tracking.add_occurrence(error, %{
        reason: "third",
        stacktrace_lines: []
      })

      result = Tracking.get_issue(account, issue.id, preload_error_with_count: true)

      # Should have only one occurrence preloaded (the most recent by inserted_at)
      # Note: count should reflect all occurrences
      assert result.error.occurrence_count == 3
      assert length(result.error.occurrences) == 1

      # The preloaded occurrence should have stacktrace lines loaded
      [occurrence] = result.error.occurrences
      assert is_list(occurrence.stacktrace_lines)
    end

    test "can combine with regular preloads" do
      {user, account} = user_with_account_fixture()
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      _error = error_fixture(issue)

      result =
        Tracking.get_issue(account, issue.id,
          preload: [:project, :submitter],
          preload_error_with_count: true
        )

      assert result.project.id == project.id
      assert result.submitter.id == user.id
      assert result.error != nil
    end
  end
end
