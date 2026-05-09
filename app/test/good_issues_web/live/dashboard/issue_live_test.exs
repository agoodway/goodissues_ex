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
      new_issue =
        issue_fixture(account, user, project, %{title: "Filter Test New Status", status: :new})

      in_progress_issue =
        issue_fixture(account, user, project, %{
          title: "Filter Test In Progress Status",
          status: :in_progress
        })

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

    test "filters incident issues by type", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)

      incident_issue =
        issue_fixture(account, user, project, %{title: "Incident Issue", type: :incident})

      _bug_issue = issue_fixture(account, user, project, %{title: "Bug Issue", type: :bug})

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      index_live
      |> form("form[phx-change='filter_type']", %{type: "incident"})
      |> render_change()

      assert_patch(index_live, ~p"/dashboard/#{account.slug}/issues?type=incident")

      html = render(index_live)
      assert html =~ incident_issue.title
      assert html =~ "INCIDENT"
      refute html =~ "Bug Issue"
    end

    test "displays issue attributes correctly", %{conn: conn, user: user, account: account} do
      project = project_fixture(account, %{name: "Test Project", prefix: "TST"})

      issue =
        issue_fixture(account, user, project, %{
          title: "Display Test Issue",
          type: :bug,
          status: :new,
          priority: :high
        })

      {:ok, _index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      assert html =~ "Display Test Issue"
      # Issue key should be displayed (TST-1)
      assert html =~ "TST-#{issue.number}"
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

    test "displays incident issue details", %{conn: conn, user: user, account: account} do
      project = project_fixture(account, %{name: "Incident Project"})

      issue =
        issue_fixture(account, user, project, %{
          title: "Database outage",
          type: :incident,
          status: :in_progress,
          priority: :critical
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "Database outage"
      assert html =~ "INCIDENT"
      assert html =~ "CRITICAL"
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
      refute html =~ ~s(value="incident")
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

  describe "Show (error data display)" do
    setup :register_and_log_in_user_with_account

    test "does not show error section when issue has no error", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Issue Without Error"})

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "Issue Without Error"
      refute html =~ "ERROR DATA"
    end

    test "shows error section when issue has linked error", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Issue With Error"})

      _error =
        error_fixture(issue, %{kind: "Elixir.RuntimeError", reason: "something went wrong"})

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "Issue With Error"
      assert html =~ "ERROR DATA"
      assert html =~ "Elixir.RuntimeError"
      assert html =~ "something went wrong"
      assert html =~ "UNRESOLVED"
    end

    test "shows error metadata correctly", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      _error =
        error_fixture(issue, %{
          kind: "Elixir.ArgumentError",
          reason: "invalid argument",
          muted: true
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "Elixir.ArgumentError"
      assert html =~ "invalid argument"
      assert html =~ "MUTED"
    end

    test "shows occurrence count", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      # Add more occurrences
      Tracking.add_occurrence(error, %{reason: "second", stacktrace_lines: []})
      Tracking.add_occurrence(error, %{reason: "third", stacktrace_lines: []})

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Should show occurrence count of 3
      assert html =~ "OCCURRENCES"
      # The count "3" should appear - using regex to match the structure
      assert html =~ ~r/OCCURRENCES.*\n.*3/s or html =~ ">3</span>"
    end

    test "stacktrace is collapsed by default", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      _error =
        error_fixture(issue, %{}, %{
          stacktrace_lines: [
            %{module: "MyApp.Worker", function: "perform", arity: 2, file: "worker.ex", line: 42}
          ]
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Should show stacktrace toggle but not the expanded content
      assert html =~ "STACKTRACE"
      assert html =~ "hero-chevron-right"
      refute html =~ "MyApp.Worker.perform/2"
    end

    test "clicking stacktrace toggle expands stacktrace", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      _error =
        error_fixture(issue, %{}, %{
          stacktrace_lines: [
            %{module: "MyApp.Worker", function: "perform", arity: 2, file: "worker.ex", line: 42}
          ]
        })

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Click to expand
      html = render_click(show_live, "toggle_stacktrace", %{})

      assert html =~ "hero-chevron-down"
      assert html =~ "MyApp.Worker.perform/2"
      assert html =~ "(worker.ex:42)"
    end

    test "clicking stacktrace toggle again collapses stacktrace", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)

      _error =
        error_fixture(issue, %{}, %{
          stacktrace_lines: [
            %{module: "MyApp.Worker", function: "perform", arity: 2, file: "worker.ex", line: 42}
          ]
        })

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Expand
      render_click(show_live, "toggle_stacktrace", %{})
      # Collapse
      html = render_click(show_live, "toggle_stacktrace", %{})

      assert html =~ "hero-chevron-right"
      refute html =~ "MyApp.Worker.perform/2"
    end

    test "owner sees mute and status toggle controls", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      _error = error_fixture(issue, %{muted: false, status: :unresolved})

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ ~s(phx-click="toggle_muted")
      assert html =~ ~s(phx-click="toggle_status")
      assert html =~ "MUTE"
      assert html =~ "RESOLVE"
    end

    test "owner can toggle muted status", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue, %{muted: false})

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Toggle to muted
      html = render_click(show_live, "toggle_muted", %{})

      # Should now show MUTED
      assert html =~ "MUTED"

      # Verify in database
      updated_error = Tracking.get_error(account, error.id)
      assert updated_error.muted == true
    end

    test "owner can toggle resolved status", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Toggle to resolved
      html = render_click(show_live, "toggle_status", %{})

      # Should now show RESOLVED and UNRESOLVE button
      assert html =~ "RESOLVED"
      assert html =~ "UNRESOLVE"

      # Verify in database
      updated_error = Tracking.get_error(account, error.id)
      assert updated_error.status == :resolved
    end

    test "owner can toggle back to unresolved", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project)
      error = error_fixture(issue)
      {:ok, _} = Tracking.update_error(error, %{status: :resolved})

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Toggle back to unresolved
      html = render_click(show_live, "toggle_status", %{})

      assert html =~ "UNRESOLVED"
      assert html =~ "RESOLVE"

      # Verify in database
      updated_error = Tracking.get_error(account, error.id)
      assert updated_error.status == :unresolved
    end
  end

  describe "Show error controls (member cannot manage)" do
    setup do
      owner = user_fixture()
      account = account_fixture(owner, %{name: "Member Error Test Account"})
      member = user_fixture()
      {:ok, _account_user} = Accounts.add_user_to_account(account, member, :member)

      conn =
        build_conn()
        |> log_in_user(member)

      %{conn: conn, member: member, account: account, owner: owner}
    end

    test "member sees error data but not toggle controls", %{
      conn: conn,
      owner: owner,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, owner, project)
      _error = error_fixture(issue, %{kind: "TestError", reason: "test reason"})

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Should see error data
      assert html =~ "ERROR DATA"
      assert html =~ "TestError"
      assert html =~ "test reason"

      # Should not see toggle controls
      refute html =~ ~s(phx-click="toggle_muted")
      refute html =~ ~s(phx-click="toggle_status")
    end

    test "member cannot toggle muted by sending event directly", %{
      conn: conn,
      owner: owner,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, owner, project)
      error = error_fixture(issue, %{muted: false})

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Attempt to send toggle event directly
      html = render_click(show_live, "toggle_muted", %{})

      assert html =~ "You don&#39;t have permission to modify errors"

      # Error should remain unchanged
      unchanged_error = Tracking.get_error(account, error.id)
      assert unchanged_error.muted == false
    end

    test "member cannot toggle status by sending event directly", %{
      conn: conn,
      owner: owner,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, owner, project)
      error = error_fixture(issue)

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Attempt to send toggle event directly
      html = render_click(show_live, "toggle_status", %{})

      assert html =~ "You don&#39;t have permission to modify errors"

      # Error should remain unchanged
      unchanged_error = Tracking.get_error(account, error.id)
      assert unchanged_error.status == :unresolved
    end
  end

  describe "Index (realtime updates)" do
    setup :register_and_log_in_user_with_account

    test "receives flash notification when issue is created via API", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account, %{prefix: "RT"})

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      # Create an issue (simulating API creation)
      {:ok, _issue} =
        Tracking.create_issue(account, user, %{
          title: "API Created Issue",
          type: :bug,
          project_id: project.id
        })

      # The LiveView should receive the PubSub message and show a flash
      html = render(index_live)
      assert html =~ "New issue created: RT-1"
    end

    test "increments total count when issue is created", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)

      {:ok, index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues")
      assert html =~ "0 issues"

      # Create an issue
      {:ok, _issue} =
        Tracking.create_issue(account, user, %{
          title: "New Issue",
          type: :bug,
          project_id: project.id
        })

      html = render(index_live)
      assert html =~ "1 issues"
    end

    test "updates issue in list when issue is updated", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Original Title", status: :new})

      {:ok, index_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues")
      assert html =~ "Original Title"
      assert html =~ "NEW"

      # Update the issue
      {:ok, _updated} =
        Tracking.update_issue(issue, %{title: "Updated Title", status: :in_progress})

      html = render(index_live)
      assert html =~ "Updated Title"
      assert html =~ "IN PROGRESS"
    end

    test "removes issue from list when filter no longer matches", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Filterable Issue", status: :new})

      # View issues filtered by status=new
      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues?status=new")

      html = render(index_live)
      assert html =~ "Filterable Issue"
      assert html =~ "1 issues"

      # Update issue status to in_progress (no longer matches filter)
      {:ok, _updated} = Tracking.update_issue(issue, %{status: :in_progress})

      html = render(index_live)
      refute html =~ "Filterable Issue"
      assert html =~ "0 issues"
    end

    test "does not update issues from other accounts", %{conn: conn, account: account} do
      _project = project_fixture(account)

      # Create another account with its own issue
      other_user = user_fixture()
      other_account = account_fixture(other_user, %{name: "Other Account"})
      other_project = project_fixture(other_account, %{prefix: "OTH"})

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      # Create issue in the other account
      {:ok, _other_issue} =
        Tracking.create_issue(other_account, other_user, %{
          title: "Other Account Issue",
          type: :bug,
          project_id: other_project.id
        })

      # Should not see notification or count update for other account's issue
      html = render(index_live)
      refute html =~ "New issue created: OTH-1"
      assert html =~ "0 issues"
    end
  end

  describe "Show (telemetry display)" do
    setup :register_and_log_in_user_with_account

    test "does not show telemetry section for issue without error", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "No Error Issue"})

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "No Error Issue"
      refute html =~ "Request Timeline"
    end

    test "does not show telemetry section when error has no request_id in context", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Error Without Request ID"})

      _error =
        error_fixture(issue, %{kind: "Elixir.RuntimeError", reason: "no request_id"}, %{
          context: %{"user_id" => 123}
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "Error Without Request ID"
      assert html =~ "Error Details"
      refute html =~ "Request Timeline"
    end

    test "shows empty telemetry state when request_id exists but no spans", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Error With No Spans"})

      _error =
        error_fixture(issue, %{kind: "Elixir.RuntimeError", reason: "test error"}, %{
          context: %{"request_id" => "req-no-spans"}
        })

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "Request Timeline"
      assert html =~ "req-no-spans"
      assert html =~ "No telemetry data found for this request"
    end

    test "displays telemetry spans when request_id matches", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Error With Telemetry"})

      _error =
        error_fixture(issue, %{kind: "Elixir.RuntimeError", reason: "test error"}, %{
          context: %{"request_id" => "req-with-spans"}
        })

      # Create telemetry spans with matching request_id
      {:ok, _} =
        FF.Telemetry.create_spans_batch(account, project.id, [
          %{
            "request_id" => "req-with-spans",
            "event_type" => "phoenix_request",
            "event_name" => "phoenix.endpoint.stop",
            "timestamp" => DateTime.to_iso8601(~U[2026-01-30 12:00:00Z]),
            "duration_ms" => 42.5,
            "context" => %{"method" => "GET", "path" => "/api/test"},
            "measurements" => %{"duration" => 42_500_000}
          },
          %{
            "request_id" => "req-with-spans",
            "event_type" => "ecto_query",
            "event_name" => "app.repo.query",
            "timestamp" => DateTime.to_iso8601(~U[2026-01-30 12:00:01Z]),
            "duration_ms" => 15.0,
            "context" => %{"source" => "users"},
            "measurements" => %{"query_time" => 15_000_000}
          }
        ])

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "Request Timeline"
      assert html =~ "req-with-spans"
      # Should show both spans
      assert html =~ "phoenix.endpoint.stop"
      assert html =~ "app.repo.query"
      # Should show duration
      assert html =~ "43ms" or html =~ "42ms"
      assert html =~ "15ms"
      # Should show event type badges
      assert html =~ "Request"
      assert html =~ "Query"
    end

    test "clicking span expands to show details", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Expandable Spans"})

      _error =
        error_fixture(issue, %{kind: "Elixir.RuntimeError", reason: "test error"}, %{
          context: %{"request_id" => "req-expandable"}
        })

      {:ok, 1} =
        FF.Telemetry.create_spans_batch(account, project.id, [
          %{
            "request_id" => "req-expandable",
            "event_type" => "phoenix_request",
            "event_name" => "test.event",
            "timestamp" => DateTime.to_iso8601(DateTime.utc_now()),
            "context" => %{"method" => "POST", "path" => "/api/users"},
            "measurements" => %{"total_time" => 100_000}
          }
        ])

      {:ok, show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Initially, details should not be visible
      refute html =~ "method"
      refute html =~ "POST"

      # Get span ID from the page
      [span] =
        FF.Telemetry.list_spans_by_request_id_for_project(account, project.id, "req-expandable")

      # Click to expand
      html = render_click(show_live, "toggle_span", %{"id" => span.id})

      # Now details should be visible
      assert html =~ "Context"
      assert html =~ "method"
      assert html =~ "POST"
      assert html =~ "Measurements"
      assert html =~ "total_time"
    end

    test "clicking expanded span collapses it", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Collapsible Spans"})

      _error =
        error_fixture(issue, %{kind: "Elixir.RuntimeError", reason: "test error"}, %{
          context: %{"request_id" => "req-collapsible"}
        })

      {:ok, 1} =
        FF.Telemetry.create_spans_batch(account, project.id, [
          %{
            "request_id" => "req-collapsible",
            "event_type" => "phoenix_request",
            "event_name" => "test.collapse",
            "timestamp" => DateTime.to_iso8601(DateTime.utc_now()),
            "context" => %{"key" => "value"}
          }
        ])

      {:ok, show_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      [span] =
        FF.Telemetry.list_spans_by_request_id_for_project(account, project.id, "req-collapsible")

      # Expand
      html = render_click(show_live, "toggle_span", %{"id" => span.id})
      assert html =~ "key"
      assert html =~ "value"

      # Collapse
      html = render_click(show_live, "toggle_span", %{"id" => span.id})
      refute html =~ "Context"
    end

    test "shows spans in chronological order", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{title: "Ordered Spans"})

      _error =
        error_fixture(issue, %{kind: "Elixir.RuntimeError", reason: "test error"}, %{
          context: %{"request_id" => "req-ordered"}
        })

      # Create spans out of order
      {:ok, 3} =
        FF.Telemetry.create_spans_batch(account, project.id, [
          %{
            "request_id" => "req-ordered",
            "event_type" => "ecto_query",
            "event_name" => "third.event",
            "timestamp" => DateTime.to_iso8601(~U[2026-01-30 12:00:02Z])
          },
          %{
            "request_id" => "req-ordered",
            "event_type" => "phoenix_request",
            "event_name" => "first.event",
            "timestamp" => DateTime.to_iso8601(~U[2026-01-30 12:00:00Z])
          },
          %{
            "request_id" => "req-ordered",
            "event_type" => "phoenix_router",
            "event_name" => "second.event",
            "timestamp" => DateTime.to_iso8601(~U[2026-01-30 12:00:01Z])
          }
        ])

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      # Check that spans appear in chronological order
      first_pos = :binary.match(html, "first.event") |> elem(0)
      second_pos = :binary.match(html, "second.event") |> elem(0)
      third_pos = :binary.match(html, "third.event") |> elem(0)

      assert first_pos < second_pos
      assert second_pos < third_pos
    end

    test "only shows spans from the correct project", %{
      conn: conn,
      user: user,
      account: account
    } do
      project = project_fixture(account)
      other_project = project_fixture(account, %{name: "Other Project", prefix: "OTH"})
      issue = issue_fixture(account, user, project, %{title: "Project Scoped Spans"})

      _error =
        error_fixture(issue, %{kind: "Elixir.RuntimeError", reason: "test error"}, %{
          context: %{"request_id" => "req-scoped"}
        })

      # Create span in correct project
      {:ok, 1} =
        FF.Telemetry.create_spans_batch(account, project.id, [
          %{
            "request_id" => "req-scoped",
            "event_type" => "phoenix_request",
            "event_name" => "correct.project.event"
          }
        ])

      # Create span with same request_id in different project
      {:ok, 1} =
        FF.Telemetry.create_spans_batch(account, other_project.id, [
          %{
            "request_id" => "req-scoped",
            "event_type" => "phoenix_request",
            "event_name" => "wrong.project.event"
          }
        ])

      {:ok, _show_live, html} = live(conn, ~p"/dashboard/#{account.slug}/issues/#{issue.id}")

      assert html =~ "correct.project.event"
      refute html =~ "wrong.project.event"
    end
  end
end
