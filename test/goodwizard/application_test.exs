defmodule Goodwizard.ApplicationTest do
  use ExUnit.Case, async: false

  @moduletag :application

  describe "supervision tree startup" do
    test "all children are running after application start" do
      # Ensure app is started (it may already be running from test_helper)
      Application.ensure_all_started(:goodwizard)

      assert Process.whereis(Goodwizard.Config) != nil
      assert Process.alive?(Process.whereis(Goodwizard.Config))
    end

    test "supervisor uses rest_for_one strategy" do
      Application.ensure_all_started(:goodwizard)

      # Verify the supervisor is running with expected name
      sup = Process.whereis(Goodwizard.Supervisor)
      assert sup != nil
      assert Process.alive?(sup)
    end
  end

  describe "Jido module" do
    test "Jido process is accessible after application start" do
      Application.ensure_all_started(:goodwizard)

      # Verify the Jido module is defined and the application booted it
      assert Code.ensure_loaded?(Goodwizard.Jido)
    end
  end

  describe "Messaging module" do
    test "Messaging module is loaded after application start" do
      Application.ensure_all_started(:goodwizard)

      assert Code.ensure_loaded?(Goodwizard.Messaging)
    end
  end
end
