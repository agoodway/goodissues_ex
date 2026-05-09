defmodule FF.MonitoringPubSubTest do
  use FF.DataCase, async: false

  import FF.AccountsFixtures
  import FF.MonitoringFixtures
  import FF.TrackingFixtures

  alias FF.Monitoring

  setup do
    {user, account} = user_with_account_fixture()
    project = project_fixture(account)
    {:ok, user: user, account: account, project: project}
  end

  describe "PubSub broadcasts" do
    test "create_check/3 broadcasts :check_created", %{
      user: user,
      account: account,
      project: project
    } do
      Phoenix.PubSub.subscribe(FF.PubSub, Monitoring.checks_topic(project.id))

      attrs = %{name: "Health", url: "https://example.com", project_id: project.id}
      {:ok, check} = Monitoring.create_check(account, user, attrs)

      assert_receive {:check_created, payload}
      assert payload.id == check.id
      assert payload.name == "Health"
      assert payload.url == "https://example.com"
      assert payload.status == :unknown
      assert payload.paused == false
    end

    test "update_check/2 broadcasts :check_updated", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      Phoenix.PubSub.subscribe(FF.PubSub, Monitoring.checks_topic(project.id))

      {:ok, updated} = Monitoring.update_check(check, %{name: "Renamed"})

      assert_receive {:check_updated, payload}
      assert payload.id == updated.id
      assert payload.name == "Renamed"
    end

    test "update_check/2 pausing broadcasts :check_updated with paused=true", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      Phoenix.PubSub.subscribe(FF.PubSub, Monitoring.checks_topic(project.id))

      {:ok, _updated} = Monitoring.update_check(check, %{paused: true})

      assert_receive {:check_updated, payload}
      assert payload.paused == true
    end

    test "delete_check/1 broadcasts :check_deleted", %{
      user: user,
      account: account,
      project: project
    } do
      check = check_fixture(account, user, project)
      Phoenix.PubSub.subscribe(FF.PubSub, Monitoring.checks_topic(project.id))

      {:ok, _} = Monitoring.delete_check(check)

      assert_receive {:check_deleted, %{id: id}}
      assert id == check.id
    end
  end
end
