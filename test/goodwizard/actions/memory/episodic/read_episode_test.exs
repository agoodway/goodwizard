defmodule Goodwizard.Actions.Memory.Episodic.ReadEpisodeTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Episodic.ReadEpisode
  alias Goodwizard.Memory.Episodic

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "read_episode_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    context = %{state: %{memory: %{memory_dir: tmp_dir}}}
    %{memory_dir: tmp_dir, context: context}
  end

  describe "reading an existing episode" do
    test "returns frontmatter and body", %{memory_dir: dir, context: ctx} do
      body = "## Observation\n\nSomething happened\n\n## Result\n\nFixed it"

      {:ok, fm} =
        Episodic.create(dir, %{
          "type" => "problem_solved",
          "summary" => "Fixed the thing",
          "outcome" => "success"
        }, body)

      assert {:ok, %{frontmatter: frontmatter, body: returned_body}} =
               ReadEpisode.run(%{id: fm["id"]}, ctx)

      assert frontmatter["id"] == fm["id"]
      assert frontmatter["type"] == "problem_solved"
      assert frontmatter["summary"] == "Fixed the thing"
      assert frontmatter["outcome"] == "success"
      assert returned_body =~ "Something happened"
      assert returned_body =~ "Fixed it"
    end

    test "frontmatter is a map with metadata", %{memory_dir: dir, context: ctx} do
      {:ok, fm} =
        Episodic.create(dir, %{
          "type" => "task_completion",
          "summary" => "Completed task",
          "outcome" => "success",
          "tags" => ["test"]
        }, "Body content")

      assert {:ok, %{frontmatter: frontmatter}} = ReadEpisode.run(%{id: fm["id"]}, ctx)

      assert is_map(frontmatter)
      assert is_binary(frontmatter["timestamp"])
      assert frontmatter["tags"] == ["test"]
    end
  end

  describe "reading a nonexistent episode" do
    test "returns error for nonexistent ID", %{context: ctx} do
      assert {:error, message} = ReadEpisode.run(%{id: "00000000-0000-0000-0000-000000000000"}, ctx)
      assert message =~ "not found"
    end
  end
end
