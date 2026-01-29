defmodule FFWeb.Dashboard.IssueLiveTest do
  use FFWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FF.AccountsFixtures
  import FF.TrackingFixtures

  alias FF.Accounts
  alias FF.Tracking

  describe "Index (unauthenticated)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard/test-account/issues")
      assert path =~ "/users/log-in"
    end
  end

  describe "Index (authenticated user)" do
    setup :register_and_log_in_user_with_account

    test "shows issues for the current account", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "My Test Issue"})

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      assert html =~ "Issues"
      assert html =~ issue.title
    end

    test "shows only issues from the current account", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      my_issue = issue_fixture(account, user, project, %{title: "My Account Issue"})

      # Create issue for a different account
      other_user = user_fixture()
      other_account = account_fixture(other_user, %{name: "Other Account"})
      other_project = project_fixture(other_account)

      other_issue =
        issue_fixture(other_account, other_user, other_project, %{title: "Other Account Issue"})

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      assert html =~ my_issue.title
      refute html =~ other_issue.title
    end

    test "shows empty state when no issues exist", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      assert html =~ "Issues"
      assert html =~ "No issues found"
    end

    test "filters issues by status", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      # Use unique titles that won't appear elsewhere in the UI
      new_issue = issue_fixture(account, user, project, %{title: "Filter Test New Status", status: :new})

      in_progress_issue =
        issue_fixture(account, user, project, %{title: "Filter Test In Progress Status", status: :in_progress})

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      # Filter by in_progress - this triggers push_patch, so we need to follow it
      index_live
      |> form("form[phx-change='filter_status']", %{status: "in_progress"})
      |> render_change()

      # Wait for the patch to complete
      assert_patch(index_live, ~p"/dashboard/#{account.slug}/issues?status=in_progress")

      html = render(index_live)
      assert html =~ in_progress_issue.title
      refute html =~ new_issue.title
    end

    test "filters issues by type", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      bug_issue = issue_fixture(account, user, project, %{title: "Bug Issue", type: :bug})

      feature_issue =
        issue_fixture(account, user, project, %{title: "Feature Issue", type: :feature_request})

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      # Filter by bug - this triggers push_patch, so we need to follow it
      index_live
      |> form("form[phx-change='filter_type']", %{type: "bug"})
      |> render_change()

      # Wait for the patch to complete
      assert_patch(index_live, ~p"/dashboard/#{account.slug}/issues?type=bug")

      html = render(index_live)
      assert html =~ bug_issue.title
      refute html =~ feature_issue.title
    end

    test "displays issue attributes correctly", %{conn: conn, user: user, account: account} do
      project = project_fixture(account, %{name: "Test Project"})

      _issue =
        issue_fixture(account, user, project, %{
          title: "Display Test Issue",
          type: :bug,
          status: :new,
          priority: :high
        })

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      assert html =~ "Display Test Issue"
      assert html =~ "Test Project"
      assert html =~ "BUG"
      assert html =~ "NEW"
    end
  end

  describe "Index pagination" do
    setup :register_and_log_in_user_with_account

    test "paginates issues correctly", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)

      # Create 25 issues to have 2 pages (20 per page)
      for i <- 1..25 do
        issue_fixture(account, user, project, %{
          title: "Issue #{String.pad_leading("#{i}", 2, "0")}"
        })
      end

      {:ok, index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      # Should show pagination
      assert html =~ "1/2"

      # Navigate to page 2
      html =
        index_live
        |> element("a[href*='page=2']")
        |> render_click()

      assert html =~ "2/2"
    end

    test "shows correct count in footer", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)

      for i <- 1..5 do
        issue_fixture(account, user, project, %{title: "Issue #{i}"})
      end

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      assert html =~ "[1-5] of 5"
    end

    test "handles invalid page parameter gracefully", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue_fixture(account, user, project, %{title: "Test Issue"})

      # Invalid page values should default to page 1
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues?page=invalid")
      assert html =~ "Test Issue"

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues?page=-1")
      assert html =~ "Test Issue"

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues?page=0")
      assert html =~ "Test Issue"

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues?page=1abc")
      assert html =~ "Test Issue"
    end

    test "handles invalid filter parameters gracefully", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue_fixture(account, user, project, %{title: "Test Issue", status: :new})

      # Invalid filter values should be ignored
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues?status=bad")
      assert html =~ "Test Issue"

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues?type=invalid")
      assert html =~ "Test Issue"
    end
  end

  describe "Index (owner/admin can manage)" do
    setup :register_and_log_in_user_with_account

    test "owner sees 'New Issue' button", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      assert html =~ "New Issue"
    end

    test "clicking an issue navigates to show page", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Clickable Issue"})

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      {:ok, _show_live, html} =
        index_live
        |> element("#issue-#{issue.id}")
        |> render_click()
        |> follow_redirect(conn)

      assert html =~ "Clickable Issue"
      assert html =~ "DESCRIPTION"
      assert html =~ "DETAILS"
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

    test "member does not see 'New Issue' button", %{conn: conn, account: account} do
      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      refute html =~ ~s(href="/dashboard/#{account.slug}/issues/new")
    end
  end

  describe "Show (authenticated user)" do
    setup :register_and_log_in_user_with_account

    test "displays issue details for current account", %{conn: conn, user: user, account: account} do
      project = project_fixture(account, %{name: "Show Test Project"})

      issue =
        issue_fixture(account, user, project, %{
          title: "Show Test Issue",
          description: "This is a test description",
          type: :bug,
          status: :in_progress,
          priority: :high
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "Show Test Issue"
      assert html =~ "This is a test description"
      assert html =~ "Show Test Project"
      assert html =~ "BUG"
      assert html =~ "IN PROGRESS"
      assert html =~ "HIGH"
    end

    test "redirects when issue belongs to different account", %{conn: conn, account: account} do
      other_user = user_fixture()
      other_account = account_fixture(other_user, %{name: "Other Account"})
      other_project = project_fixture(other_account)

      other_issue =
        issue_fixture(other_account, other_user, other_project, %{title: "Other Issue"})

      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/dashboard/#{account.slug}/issues/#{other_issue.id}")

      assert path == "/dashboard/#{account.slug}/issues"
      assert flash["error"] == "Issue not found."
    end

    test "redirects for invalid issue id", %{conn: conn, account: account} do
      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/dashboard/#{account.slug}/issues/invalid-uuid")

      assert path == "/dashboard/#{account.slug}/issues"
      assert flash["error"] == "Issue not found."
    end

    test "owner sees edit and delete buttons", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Manageable Issue"})

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "Edit"
      assert html =~ "Delete"
    end

    test "owner can delete issue from show page", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Delete Me"})

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      {:ok, _index_live, html} =
        show_live
        |> element("button[phx-click='delete']")
        |> render_click()
        |> follow_redirect(conn, ~p"/dashboard/#{account.slug}/issues")

      assert html =~ "Issue deleted successfully"
      refute html =~ "Delete Me"

      # Verify in database
      assert Tracking.get_issue(account, issue.id) == nil
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

    test "member does not see edit or delete buttons", %{
      conn: conn,
      owner: owner,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, owner, project, %{title: "Read Only Issue"})

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "Read Only Issue"
      refute html =~ ~s(phx-click="delete")
      assert html =~ "Read-only access"
    end

    test "member cannot delete issue by sending event directly", %{
      conn: conn,
      owner: owner,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, owner, project, %{title: "Protected Issue"})

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Attempt to send delete event directly (bypassing UI)
      html = render_click(show_live, "delete", %{})

      # Should show permission error
      assert html =~ "You don&#39;t have permission to delete issues"

      # Issue should still exist
      assert Tracking.get_issue(account, issue.id) != nil
    end

    test "member cannot access edit modal via direct URL", %{
      conn: conn,
      owner: owner,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, owner, project, %{title: "Protected Issue"})

      # Should be redirected back to show page with error flash
      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}/edit")

      assert path == "/dashboard/#{account.slug}/issues/#{issue.id}"
      assert flash["error"] == "You don't have permission to edit issues."
    end
  end

  describe "Edit (authenticated owner)" do
    setup :register_and_log_in_user_with_account

    test "opens edit modal and updates issue", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Original Title", type: :bug})

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Click edit to open modal
      show_live
      |> element("a", "Edit")
      |> render_click()

      assert_patch(show_live, ~p"/dashboard/#{account.slug}/issues/#{issue.id}/edit")

      # Update the issue
      show_live
      |> form("#issue-form", issue: %{title: "Updated Title", status: "in_progress"})
      |> render_submit()

      assert_patch(show_live, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      html = render(show_live)
      assert html =~ "Issue updated successfully"
      assert html =~ "Updated Title"
      assert html =~ "IN PROGRESS"

      # Verify in database
      updated_issue = Tracking.get_issue(account, issue.id)
      assert updated_issue.title == "Updated Title"
      assert updated_issue.status == :in_progress
    end

    test "validates form on submit", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Validation Test"})

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}/edit")

      html =
        show_live
        |> form("#issue-form", issue: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "New (owner/admin)" do
    setup :register_and_log_in_user_with_account

    test "displays create form", %{conn: conn, account: account} do
      project_fixture(account, %{name: "Project for New Issue"})

      {:ok, _new_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/new")

      assert html =~ "New Issue"
      assert html =~ "Title"
      assert html =~ "Project"
      assert html =~ "Type"
      assert html =~ "Project for New Issue"
    end

    test "shows empty state when no projects exist", %{conn: conn, account: account} do
      {:ok, _new_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/new")

      assert html =~ "No projects found"
      assert html =~ "create a project"
    end

    test "validates required fields", %{conn: conn, account: account} do
      project_fixture(account)

      {:ok, new_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/new")

      html =
        new_live
        |> form("#issue-form", issue: %{title: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "creates issue and redirects to show page", %{conn: conn, account: account} do
      project = project_fixture(account, %{name: "New Issue Project"})

      {:ok, new_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/new")

      {:ok, _show_live, html} =
        new_live
        |> form("#issue-form",
          issue: %{
            title: "Brand New Issue",
            project_id: project.id,
            type: "feature_request",
            priority: "high",
            description: "This is a new feature request"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Issue created successfully"
      assert html =~ "Brand New Issue"
      assert html =~ "FEATURE"
      assert html =~ "HIGH"
      assert html =~ "This is a new feature request"
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

    test "member is redirected when trying to create issue", %{conn: conn, account: account} do
      {:error, {:live_redirect, %{to: path, flash: flash}}} =
        live(conn, ~p"/dashboard/#{account.slug}/issues/new")

      assert path == "/dashboard/#{account.slug}/issues"
      assert flash["error"] == "You don't have permission to create issues."
    end
  end
end
