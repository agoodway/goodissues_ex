defmodule FF.TrackingTest do
  use FF.DataCase

  alias FF.Tracking
  alias FF.Tracking.Project

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
                 description: "A description"
               })

      assert project.name == "My Project"
      assert project.description == "A description"
      assert project.account_id == account.id
    end

    test "returns error changeset with invalid attributes" do
      {_user, account} = user_with_account_fixture()

      assert {:error, %Ecto.Changeset{}} = Tracking.create_project(account, %{name: nil})
    end

    test "creates project without description" do
      {_user, account} = user_with_account_fixture()

      assert {:ok, %Project{} = project} = Tracking.create_project(account, %{name: "My Project"})
      assert project.description == nil
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
end
