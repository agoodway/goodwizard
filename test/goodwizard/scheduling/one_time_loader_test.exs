defmodule Goodwizard.Scheduling.OneTimeLoaderTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Scheduling.{OneTimeLoader, OneTimeRegistry, OneTimeStore}

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "one_time_loader_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_config_started()

    one_time_dir = Path.join(@test_workspace, "scheduling/one_time")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(one_time_dir)

    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)

      if Process.whereis(Goodwizard.Config) do
        Goodwizard.Config.put(["agent", "workspace"], original_workspace)
      end
    end)

    %{one_time_dir: one_time_dir}
  end

  defp ensure_config_started do
    if Process.whereis(Goodwizard.Config) do
      :ok
    else
      start_supervised!(Goodwizard.Config)
      :ok
    end
  end

  describe "reload/0" do
    test "returns {:ok, 0} when no jobs exist" do
      assert {:ok, 0} = OneTimeLoader.reload()
    end

    test "reloads pending jobs with future fires_at" do
      fires_at = DateTime.utc_now() |> DateTime.add(30, :minute) |> DateTime.to_iso8601()

      OneTimeStore.save(%{
        job_id: :one_time_aa11bb22cc33dd44,
        task: "future task",
        room_id: "cli:main",
        agent_id: "test_agent",
        fires_at: fires_at,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })

      assert {:ok, 1} = OneTimeLoader.reload()

      # Verify it's registered in the registry
      assert {:ok, _tref} = OneTimeRegistry.lookup(:one_time_aa11bb22cc33dd44)

      # Cleanup
      OneTimeRegistry.cancel(:one_time_aa11bb22cc33dd44)
    end

    test "discards expired jobs and deletes their files", %{one_time_dir: one_time_dir} do
      past = DateTime.utc_now() |> DateTime.add(-60, :minute) |> DateTime.to_iso8601()

      OneTimeStore.save(%{
        job_id: :one_time_dead000000000000,
        task: "expired task",
        room_id: "cli:main",
        agent_id: "test_agent",
        fires_at: past,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })

      assert {:ok, 0} = OneTimeLoader.reload()

      # File should be cleaned up
      refute File.exists?(Path.join(one_time_dir, "one_time_dead000000000000.json"))
    end

    test "skips malformed job files and continues", %{one_time_dir: one_time_dir} do
      fires_at = DateTime.utc_now() |> DateTime.add(30, :minute) |> DateTime.to_iso8601()

      # Good job (exactly 16 hex chars after one_time_)
      OneTimeStore.save(%{
        job_id: :one_time_aabb112233445566,
        task: "good task",
        room_id: "cli:main",
        agent_id: "test_agent",
        fires_at: fires_at,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })

      # Malformed JSON file
      File.write!(Path.join(one_time_dir, "one_time_bad0000000000000a.json"), "not valid json")

      # Job with missing required fields (valid 16 hex format but no task/room_id)
      File.write!(
        Path.join(one_time_dir, "one_time_ccdd556677889900.json"),
        Jason.encode!(%{"job_id" => "one_time_ccdd556677889900"})
      )

      assert {:ok, 1} = OneTimeLoader.reload()

      # Cleanup
      OneTimeRegistry.cancel(:one_time_aabb112233445566)
    end

    test "skips jobs with invalid job_id format", %{one_time_dir: one_time_dir} do
      fires_at = DateTime.utc_now() |> DateTime.add(30, :minute) |> DateTime.to_iso8601()

      File.write!(
        Path.join(one_time_dir, "bad_prefix.json"),
        Jason.encode!(%{
          "job_id" => "bad_prefix",
          "task" => "test",
          "room_id" => "cli:main",
          "agent_id" => "test_agent",
          "fires_at" => fires_at
        })
      )

      assert {:ok, 0} = OneTimeLoader.reload()
    end

    test "reloads multiple pending jobs" do
      fires_at1 = DateTime.utc_now() |> DateTime.add(15, :minute) |> DateTime.to_iso8601()
      fires_at2 = DateTime.utc_now() |> DateTime.add(45, :minute) |> DateTime.to_iso8601()

      OneTimeStore.save(%{
        job_id: :one_time_1111aabbccddeeff,
        task: "task one",
        room_id: "cli:main",
        agent_id: "test_agent",
        fires_at: fires_at1,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })

      OneTimeStore.save(%{
        job_id: :one_time_2222aabbccddeeff,
        task: "task two",
        room_id: "cli:main",
        agent_id: "test_agent",
        fires_at: fires_at2,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })

      assert {:ok, 2} = OneTimeLoader.reload()

      assert {:ok, _} = OneTimeRegistry.lookup(:one_time_1111aabbccddeeff)
      assert {:ok, _} = OneTimeRegistry.lookup(:one_time_2222aabbccddeeff)

      # Cleanup
      OneTimeRegistry.cancel(:one_time_1111aabbccddeeff)
      OneTimeRegistry.cancel(:one_time_2222aabbccddeeff)
    end
  end
end
