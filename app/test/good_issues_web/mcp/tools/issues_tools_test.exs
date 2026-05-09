defmodule GIWeb.MCP.Tools.IssuesToolsTest do
  use GI.DataCase, async: true

  alias Anubis.Server.Frame
  alias GI.Repo
  alias GI.Tracking
  alias GIWeb.MCP.Tools.Issues.{IssuesCreate, IssuesList, IssuesUpdate}

  import GI.AccountsFixtures
  import GI.TrackingFixtures

  defp frame_with_api_key(api_key) do
    %Frame{assigns: %{api_key: Repo.preload(api_key, account_user: [:account, :user])}}
  end

  defp response_body(response) do
    response.content
    |> List.first()
    |> Map.fetch!("text")
    |> Jason.decode!()
  end

  describe "incident support" do
    test "create tool accepts incident type" do
      user = user_fixture()
      account = account_fixture(user)
      project = project_fixture(account)
      {_token, api_key} = api_key_fixture(user, account)

      {:reply, response, _frame} =
        IssuesCreate.execute(
          %{
            project_id: project.id,
            title: "Service outage",
            type: "incident",
            priority: "medium"
          },
          frame_with_api_key(api_key)
        )

      assert %{"success" => true, "data" => %{"type" => "incident", "title" => "Service outage"}} =
               response_body(response)
    end

    test "list tool filters incident issues" do
      user = user_fixture()
      account = account_fixture(user)
      project = project_fixture(account)

      incident_issue =
        issue_fixture(account, user, project, %{title: "Incident", type: :incident})

      _bug_issue = issue_fixture(account, user, project, %{title: "Bug", type: :bug})
      {_token, api_key} = api_key_fixture(user, account)

      {:reply, response, _frame} =
        IssuesList.execute(%{type: "incident"}, frame_with_api_key(api_key))

      assert %{"success" => true, "data" => [issue], "meta" => %{"total_count" => 1}} =
               response_body(response)

      assert issue["id"] == incident_issue.id
      assert issue["type"] == "incident"
    end

    test "update tool accepts incident type" do
      user = user_fixture()
      account = account_fixture(user)
      project = project_fixture(account)
      issue = issue_fixture(account, user, project, %{type: :bug})
      {_token, api_key} = api_key_fixture(user, account)

      {:reply, response, _frame} =
        IssuesUpdate.execute(%{id: issue.id, type: "incident"}, frame_with_api_key(api_key))

      assert %{"success" => true, "data" => %{"id" => id, "type" => "incident"}} =
               response_body(response)

      assert id == issue.id
      assert Tracking.get_issue(account, issue.id).type == :incident
    end
  end
end
