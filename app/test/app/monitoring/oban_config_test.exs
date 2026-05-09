defmodule FF.Monitoring.ObanConfigTest do
  use FF.DataCase, async: true

  describe "Oban plugins configuration" do
    test "no cron plugins are configured in test environment" do
      plugins = Application.get_env(:app, Oban)[:plugins]
      assert is_nil(plugins), "Expected no plugins in test, got: #{inspect(plugins)}"
    end

    test "maintenance queue is configured" do
      queues = Application.get_env(:app, Oban)[:queues]
      assert Keyword.has_key?(queues, :maintenance)
    end
  end
end
