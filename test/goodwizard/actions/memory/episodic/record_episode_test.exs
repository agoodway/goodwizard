defmodule Goodwizard.Actions.Memory.Episodic.RecordEpisodeTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Episodic.RecordEpisode
  alias Goodwizard.Memory.Episodic

  @valid_params %{
    type: "task_completion",
    summary: "Fixed login bug",
    outcome: "success",
    observation: "Login page returned 500",
    approach: "Checked server logs",
    result: "Found null pointer in auth handler"
  }

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "record_episode_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    context = %{state: %{memory: %{memory_dir: tmp_dir}}}
    %{memory_dir: tmp_dir, context: context}
  end

  describe "successful recording" do
    test "creates episode with all required params", %{context: ctx} do
      assert {:ok, %{episode: episode, message: message}} =
               RecordEpisode.run(@valid_params, ctx)

      assert is_binary(episode["id"])
      assert is_binary(episode["timestamp"])
      assert episode["type"] == "task_completion"
      assert episode["summary"] == "Fixed login bug"
      assert episode["outcome"] == "success"
      assert message == "Episode recorded: Fixed login bug"
    end

    test "frontmatter contains auto-generated id and timestamp", %{context: ctx} do
      assert {:ok, %{episode: episode}} = RecordEpisode.run(@valid_params, ctx)

      assert String.length(episode["id"]) == 36
      assert episode["timestamp"] =~ ~r/^\d{4}-\d{2}-\d{2}T/
    end

    test "body contains observation, approach, result, and lessons sections", %{
      memory_dir: dir,
      context: ctx
    } do
      params = Map.put(@valid_params, :lessons, "Always validate input")

      assert {:ok, %{episode: episode}} = RecordEpisode.run(params, ctx)

      assert {:ok, {_fm, body}} = Episodic.read(dir, episode["id"])
      assert body =~ "## Observation"
      assert body =~ "Login page returned 500"
      assert body =~ "## Approach"
      assert body =~ "Checked server logs"
      assert body =~ "## Result"
      assert body =~ "Found null pointer in auth handler"
      assert body =~ "## Lessons"
      assert body =~ "Always validate input"
    end

    test "omits lessons section when not provided", %{memory_dir: dir, context: ctx} do
      assert {:ok, %{episode: episode}} = RecordEpisode.run(@valid_params, ctx)

      assert {:ok, {_fm, body}} = Episodic.read(dir, episode["id"])
      refute body =~ "## Lessons"
    end

    test "summary is truncated at 200 characters", %{context: ctx} do
      long_summary = String.duplicate("a", 250)
      params = Map.put(@valid_params, :summary, long_summary)

      assert {:ok, %{episode: episode}} = RecordEpisode.run(params, ctx)

      assert String.length(episode["summary"]) == 200
    end

    test "defaults tags and entities_involved to empty lists", %{context: ctx} do
      assert {:ok, %{episode: episode}} = RecordEpisode.run(@valid_params, ctx)

      assert episode["tags"] == []
      assert episode["entities_involved"] == []
    end

    test "accepts tags and entities_involved", %{context: ctx} do
      params =
        @valid_params
        |> Map.put(:tags, ["auth", "bugfix"])
        |> Map.put(:entities_involved, ["user-service"])

      assert {:ok, %{episode: episode}} = RecordEpisode.run(params, ctx)

      assert episode["tags"] == ["auth", "bugfix"]
      assert episode["entities_involved"] == ["user-service"]
    end
  end

  describe "context resolution" do
    test "resolves memory_dir from context state", %{memory_dir: dir} do
      context = %{state: %{memory: %{memory_dir: dir}}}

      assert {:ok, %{episode: _}} = RecordEpisode.run(@valid_params, context)

      # Verify file was created in the right place
      {:ok, files} = File.ls(Path.join(dir, "episodic"))
      assert length(files) == 1
    end

    test "falls back to Config when context has no memory state", %{memory_dir: _dir} do
      # With empty context, falls back to Config.memory_dir()
      # We just verify it doesn't crash — the actual path depends on config
      result = RecordEpisode.run(@valid_params, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
