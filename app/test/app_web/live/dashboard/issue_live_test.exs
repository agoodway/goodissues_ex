defmodule FFWeb.Dashboard.IssueLiveTest do
  use FFWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FF.AccountsFixtures
  import FF.TrackingFixtures

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
      new_issue = issue_fixture(account, user, project, %{title: "New Issue", status: :new})

      in_progress_issue =
        issue_fixture(account, user, project, %{title: "In Progress Issue", status: :in_progress})

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      # Filter by in_progress
      html =
        index_live
        |> form("form[phx-change='filter_status']", %{status: "in_progress"})
        |> render_change()

      assert html =~ in_progress_issue.title
      refute html =~ new_issue.title
    end

    test "filters issues by type", %{conn: conn, user: user, account: account} do
      project = project_fixture(account)
      bug_issue = issue_fixture(account, user, project, %{title: "Bug Issue", type: :bug})

      feature_issue =
        issue_fixture(account, user, project, %{title: "Feature Issue", type: :feature_request})

      {:ok, index_live, _html} = live(conn, ~p"/dashboard/#{account.slug}/issues")

      # Filter by bug
      html =
        index_live
        |> form("form[phx-change='filter_type']", %{type: "bug"})
        |> render_change()

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
end
