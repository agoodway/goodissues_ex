defmodule GIWeb.Dashboard.ProjectLiveTest do
  use GIWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import GI.AccountsFixtures
  import GI.TrackingFixtures

  alias GI.Accounts
  alias GI.Tracking

  describe "Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard/test-account/projects")
      assert path =~ "/users/log-in"
    end
  end

  describe "Index (authenticated user)" do
    setup :register_and_log_in_user_with_account

    test "shows projects for the current account", %{conn: conn, account: account} do
      project = project_fixture(account, %{name: "My Test Project"})

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects")

      assert html =~ "Projects"
      assert html =~ project.name
    end

    test "shows only projects from the current account", %{conn: conn, account: account} do
      my_project = project_fixture(account, %{name: "My Account Project"})

      # Create project for a different account
      other_user = user_fixture()
      other_account = account_fixture(other_user, %{name: "Other Account"})
      other_project = project_fixture(other_account, %{name: "Other Account Project"})

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects")

      assert html =~ my_project.name
      refute html =~ other_project.name
    end

    test "shows empty state when no projects exist", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects")

      assert html =~ "Projects"
      assert html =~ "No projects found"
    end

    test "displays project attributes correctly", %{conn: conn, user: user, account: account} do
      project = project_fixture(account, %{name: "Display Test Project", prefix: "DTP"})

      # Create some issues to test count
      issue_fixture(account, user, project)
      issue_fixture(account, user, project)

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects")

      assert html =~ "Display Test Project"
      assert html =~ "DTP"
      # Check issue count is displayed
      assert html =~ "2"
    end

    test "shows issue count for each project", %{conn: conn, user: user, account: account} do
      project1 = project_fixture(account, %{name: "Project With Issues"})
      project2 = project_fixture(account, %{name: "Project Without Issues"})

      # Create 3 issues for project1
      for _ <- 1..3 do
        issue_fixture(account, user, project1)
      end

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects")

      assert html =~ project1.name
      assert html =~ project2.name
    end
  end

  describe "Index (owner can manage)" do
    setup :register_and_log_in_user_with_account

    test "owner sees 'New Project' button", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects")

      assert html =~ "New Project"
    end

    test "clicking a project navigates to show page", %{conn: conn, account: account} do
      project = project_fixture(account, %{name: "Clickable Project"})

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/projects")

      {:ok, _show_live, html} =
        index_live
        |> element("#project-#{project.id}")
        |> render_click()
        |> follow_redirect(conn)

      assert html =~ "Clickable Project"
      assert html =~ "A test project description"
    end
  end

  describe "Index (member cannot manage)" do
    setup do
      owner = user_fixture()
      account = account_fixture(owner, %{name: "Member Test Account"})
      member = user_fixture()
      {:ok, _account_user} = Accounts.add_user_to_account(account, member, :member)

      conn =
        build_conn()
        |> log_in_user(member)

      %{conn: conn, member: member, account: account, owner: owner}
    end

    test "member does not see 'New Project' button", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects")

      refute html =~ ~s(href="/dashboard/#{account.slug}/projects/new")
    end
  end

  describe "Show (authenticated user)" do
    setup :register_and_log_in_user_with_account

    test "displays project details for current account", %{conn: conn, account: account} do
      project =
        project_fixture(account, %{
          name: "Show Test Project",
          description: "This is a test description",
          prefix: "STP"
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      assert html =~ "Show Test Project"
      assert html =~ "This is a test description"
      assert html =~ "STP"
    end

    test "shows recent issues on project page", %{conn: conn, user: user, account: account} do
      project = project_fixture(account, %{name: "Project With Recent Issues"})
      issue = issue_fixture(account, user, project, %{title: "Recent Issue Title"})

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      assert html =~ "Recent Issue Title"
      assert html =~ "#{project.prefix}-#{issue.number}"
    end

    test "renders incident styling for recent incident issues", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account, %{name: "Incident Project"})
      issue_fixture(account, user, project, %{title: "Service incident", type: :incident})

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      assert has_element?(show_live, ".project-issue-type-incident")
      assert render(show_live) =~ "hero-exclamation-triangle"
    end

    test "redirects when project belongs to different account", %{conn: conn, account: account} do
      other_user = user_fixture()
      other_account = account_fixture(other_user, %{name: "Other Account"})
      other_project = project_fixture(other_account, %{name: "Other Project"})

      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{other_project.id}")

      assert path == "/dashboard/#{account.slug}/projects"
      assert flash["error"] == "Project not found."
    end

    test "redirects for invalid project id", %{conn: conn, account: account} do
      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/invalid-uuid")

      assert path == "/dashboard/#{account.slug}/projects"
      assert flash["error"] == "Project not found."
    end

    test "owner sees edit and delete buttons", %{conn: conn, account: account} do
      project = project_fixture(account, %{name: "Manageable Project"})

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      assert html =~ "Edit"
      assert html =~ "Delete"
    end

    test "owner can delete project from show page", %{conn: conn, account: account} do
      project = project_fixture(account, %{name: "Delete Me"})

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      {:ok, _index_live, html} =
        show_live
        |> element("button[phx-click='delete']")
        |> render_click()
        |> follow_redirect(conn, ~p"/dashboard/#{account.slug}/projects")

      assert html =~ "Project deleted successfully"
      refute html =~ "Delete Me"

      # Verify in database
      assert Tracking.get_project(account, project.id) == nil
    end
  end

  describe "Show (member cannot manage)" do
    setup do
      owner = user_fixture()
      account = account_fixture(owner, %{name: "Member Test Account"})
      member = user_fixture()
      {:ok, _account_user} = Accounts.add_user_to_account(account, member, :member)

      conn =
        build_conn()
        |> log_in_user(member)

      %{conn: conn, member: member, account: account, owner: owner}
    end

    test "member does not see edit or delete buttons", %{conn: conn, account: account} do
      project = project_fixture(account, %{name: "Read Only Project"})

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      assert html =~ "Read Only Project"
      refute html =~ ~s(phx-click="delete")
      assert html =~ "Read-only access"
    end

    test "member cannot delete project by sending event directly", %{conn: conn, account: account} do
      project = project_fixture(account, %{name: "Protected Project"})

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      # Attempt to send delete event directly (bypassing UI)
      html = render_click(show_live, "delete", %{})

      # Should show permission error
      assert html =~ "You don&#39;t have permission to delete projects"

      # Project should still exist
      assert Tracking.get_project(account, project.id) != nil
    end

    test "member cannot access edit modal via direct URL", %{conn: conn, account: account} do
      project = project_fixture(account, %{name: "Protected Project"})

      # Should be redirected back to show page with error flash
      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/edit")

      assert path == "/dashboard/#{account.slug}/projects/#{project.id}"
      assert flash["error"] == "You don't have permission to edit projects."
    end
  end

  describe "Edit (authenticated owner)" do
    setup :register_and_log_in_user_with_account

    test "opens edit modal and updates project", %{conn: conn, account: account} do
      project = project_fixture(account, %{name: "Original Name", prefix: "ORG"})

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}")

      # Click edit to open modal

      # Click edit to open modal
      show_live
      |> element("a", "Edit")
      |> render_click()

      assert_patch(show_live, ~p"/dashboard/#{account.slug}/projects/#{project.id}/edit")

      # Update the project
      {:ok, _show_live, html} =
        show_live
        |> form("#project-form", project: %{name: "Updated Name", description: "New description"})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Project updated successfully"
      assert html =~ "Updated Name"
      assert html =~ "New description"

      # Verify in database
      updated_project = Tracking.get_project(account, project.id)
      assert updated_project.name == "Updated Name"
      assert updated_project.description == "New description"
    end

    test "validates form on change", %{conn: conn, account: account} do
      project = project_fixture(account, %{name: "Validation Test"})

      {:ok, show_live, _html} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/#{project.id}/edit")

      # Invalid prefix format
      html =
        show_live
        |> form("#project-form", project: %{prefix: "te-st"})
        |> render_change()

      assert html =~ "must be uppercase letters and numbers only"
    end
  end

  describe "New (owner/admin)" do
    setup :register_and_log_in_user_with_account

    test "displays create form", %{conn: conn, account: account} do
      {:ok, _new_live, html} = live(conn, ~p"/dashboard/#{account.slug}/projects/new")

      assert html =~ "New Project"
      assert html =~ "Name"
      assert html =~ "Prefix"
      assert html =~ "Description"
    end

    test "validates required fields", %{conn: conn, account: account} do
      {:ok, new_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/projects/new")

      html =
        new_live
        |> form("#project-form", project: %{name: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "suggests prefix from name", %{conn: conn, account: account} do
      {:ok, new_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/projects/new")

      html =
        new_live
        |> form("#project-form", project: %{name: "My Cool Project"})
        |> render_change()

      # Should suggest MCP from "My Cool Project"
      assert html =~ "MCP"
    end

    test "creates project and redirects to show page", %{conn: conn, account: account} do
      {:ok, new_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/projects/new")

      {:ok, _show_live, html} =
        new_live
        |> form("#project-form",
          project: %{
            name: "Brand New Project",
            prefix: "BNP",
            description: "A brand new project description"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Project created successfully"
      assert html =~ "Brand New Project"
      assert html =~ "BNP"
      assert html =~ "A brand new project description"
    end

    test "validates prefix uniqueness", %{conn: conn, account: account} do
      # Create a project with prefix "DUP"
      project_fixture(account, %{prefix: "DUP"})

      {:ok, new_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/projects/new")

      html =
        new_live
        |> form("#project-form", project: %{name: "Another Project", prefix: "DUP"})
        |> render_submit()

      assert html =~ "already exists in this account"
    end
  end

  describe "New (member cannot access)" do
    setup do
      owner = user_fixture()
      account = account_fixture(owner, %{name: "Member Test Account"})
      member = user_fixture()
      {:ok, _account_user} = Accounts.add_user_to_account(account, member, :member)

      conn =
        build_conn()
        |> log_in_user(member)

      %{conn: conn, member: member, account: account}
    end

    test "member is redirected when trying to create project", %{conn: conn, account: account} do
      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/dashboard/#{account.slug}/projects/new")

      assert path == "/dashboard/#{account.slug}/projects"
      assert flash["error"] == "You don't have permission to create projects."
    end
  end
end
