defmodule FF.TrackingTest do
  use FF.DataCase

  alias FF.Tracking
  alias FF.Tracking.{Issue, Project}

  import FF.AccountsFixtures
  import FF.TrackingFixtures

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

      assert Tracking.get_issue(account, issue.id) == issue
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
end
