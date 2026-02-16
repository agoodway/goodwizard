defmodule Goodwizard.Actions.Scheduling.ListCronJobsTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Scheduling.ListCronJobs

  # A minimal GenServer that mimics AgentServer's :get_state response
  defmodule FakeAgentServer do
    use GenServer

    def start_link(cron_jobs) do
      GenServer.start_link(__MODULE__, cron_jobs)
    end

    @impl true
    def init(cron_jobs), do: {:ok, cron_jobs}

    @impl true
    def handle_call(:get_state, _from, cron_jobs) do
      {:reply, {:ok, %{cron_jobs: cron_jobs}}, cron_jobs}
    end
  end

  describe "run/2" do
    test "returns empty list and count 0 when no agent_id in context" do
      assert {:ok, result} = ListCronJobs.run(%{}, %{})
      assert result.jobs == []
      assert result.count == 0
    end

    test "returns empty list and count 0 when agent_id not found" do
      assert {:ok, result} = ListCronJobs.run(%{}, %{agent_id: "nonexistent_agent"})
      assert result.jobs == []
      assert result.count == 0
    end

    test "returns job descriptors when cron_jobs exist" do
      scheduler_pid = spawn(fn -> Process.sleep(:infinity) end)

      cron_jobs = %{
        cron_123: scheduler_pid,
        cron_456: scheduler_pid
      }

      {:ok, server_pid} = FakeAgentServer.start_link(cron_jobs)

      assert {:ok, result} = ListCronJobs.run(%{}, %{agent_id: server_pid})
      assert result.count == 2

      job_ids = Enum.map(result.jobs, & &1.job_id) |> Enum.sort()
      assert job_ids == ["cron_123", "cron_456"]

      assert Enum.all?(result.jobs, &(&1.active == true))

      Process.exit(scheduler_pid, :kill)
      GenServer.stop(server_pid)
    end

    test "returns empty list and count 0 when no cron jobs are active" do
      {:ok, server_pid} = FakeAgentServer.start_link(%{})

      assert {:ok, result} = ListCronJobs.run(%{}, %{agent_id: server_pid})
      assert result.jobs == []
      assert result.count == 0

      GenServer.stop(server_pid)
    end

    test "job descriptor contains job_id as string and active field" do
      scheduler_pid = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, server_pid} = FakeAgentServer.start_link(%{cron_abc: scheduler_pid})

      assert {:ok, result} = ListCronJobs.run(%{}, %{agent_id: server_pid})
      [job] = result.jobs

      assert is_binary(job.job_id)
      assert job.job_id == "cron_abc"
      assert Map.has_key?(job, :active)
      assert job.active == true

      Process.exit(scheduler_pid, :kill)
      GenServer.stop(server_pid)
    end

    test "reports inactive when scheduler process is dead" do
      scheduler_pid = spawn(fn -> :ok end)
      # Wait for process to die
      Process.sleep(10)

      {:ok, server_pid} = FakeAgentServer.start_link(%{cron_dead: scheduler_pid})

      assert {:ok, result} = ListCronJobs.run(%{}, %{agent_id: server_pid})
      [job] = result.jobs

      assert job.job_id == "cron_dead"
      assert job.active == false

      GenServer.stop(server_pid)
    end
  end
end
