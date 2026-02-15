defmodule Goodwizard.Brain.IdTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.Id

  setup do
    workspace = Path.join(System.tmp_dir!(), "brain_id_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(Path.join([workspace, "brain"]))
    on_exit(fn -> File.rm_rf!(workspace) end)
    %{workspace: workspace}
  end

  describe "generate/1" do
    test "generates a valid ID", %{workspace: workspace} do
      assert {:ok, id} = Id.generate(workspace)
      assert is_binary(id)
      assert String.length(id) >= 8
      assert Id.valid?(id)
    end

    test "generates unique IDs on successive calls", %{workspace: workspace} do
      {:ok, id1} = Id.generate(workspace)
      {:ok, id2} = Id.generate(workspace)
      {:ok, id3} = Id.generate(workspace)

      assert id1 != id2
      assert id2 != id3
      assert id1 != id3
    end

    test "increments counter file", %{workspace: workspace} do
      counter_path = Path.join([workspace, "brain", ".counter"])

      Id.generate(workspace)
      assert File.read!(counter_path) == "1"

      Id.generate(workspace)
      assert File.read!(counter_path) == "2"

      Id.generate(workspace)
      assert File.read!(counter_path) == "3"
    end

    test "creates counter file if it doesn't exist", %{workspace: workspace} do
      counter_path = Path.join([workspace, "brain", ".counter"])
      refute File.exists?(counter_path)

      {:ok, _id} = Id.generate(workspace)
      assert File.exists?(counter_path)
    end

    test "resumes from existing counter value", %{workspace: workspace} do
      counter_path = Path.join([workspace, "brain", ".counter"])
      File.write!(counter_path, "100")

      {:ok, _id} = Id.generate(workspace)
      assert File.read!(counter_path) == "101"
    end

    test "handles corrupted counter file gracefully", %{workspace: workspace} do
      counter_path = Path.join([workspace, "brain", ".counter"])
      File.write!(counter_path, "not_a_number")

      assert {:ok, id} = Id.generate(workspace)
      assert Id.valid?(id)
      # Counter resets to 0, increments to 1
      assert File.read!(counter_path) == "1"
    end

    test "returns error when counter directory is unwritable", _context do
      # Use a path under /dev/null which can't be a directory
      workspace = "/dev/null/impossible"
      assert {:error, _reason} = Id.generate(workspace)
    end

    test "generates unique IDs under concurrent access", %{workspace: workspace} do
      ids =
        1..50
        |> Task.async_stream(fn _ -> Id.generate(workspace) end, max_concurrency: 10)
        |> Enum.map(fn {:ok, {:ok, id}} -> id end)

      assert length(ids) == 50
      assert length(Enum.uniq(ids)) == 50
    end

    test "cleans up stale lock file and succeeds", %{workspace: workspace} do
      counter_file = Path.join([workspace, "brain", ".counter"])
      lock_file = counter_file <> ".lock"

      # Create a stale lock file with old mtime
      File.write!(lock_file, "")
      # Set mtime to 60 seconds ago
      past = NaiveDateTime.add(NaiveDateTime.utc_now(), -60)
      File.touch!(lock_file, NaiveDateTime.to_erl(past))

      assert {:ok, id} = Id.generate(workspace)
      assert Id.valid?(id)
      refute File.exists?(lock_file)
    end

    test "recovers counter from existing entities across type directories", %{
      workspace: workspace
    } do
      counter_file = Path.join([workspace, "brain", ".counter"])
      brain_dir = Path.join(workspace, "brain")

      # Create some entity files in different type directories
      people_dir = Path.join(brain_dir, "people")
      tasks_dir = Path.join(brain_dir, "tasks")
      File.mkdir_p!(people_dir)
      File.mkdir_p!(tasks_dir)

      # Generate some IDs to get entity filenames
      {:ok, sqids} = Sqids.new(alphabet: "abcdefghijklmnopqrstuvwxyz0123456789", min_length: 8)
      id_5 = Sqids.encode!(sqids, [5])
      id_10 = Sqids.encode!(sqids, [10])
      id_15 = Sqids.encode!(sqids, [15])

      File.write!(Path.join(people_dir, "#{id_5}.md"), "---\nid: #{id_5}\nname: A\n---\n")
      File.write!(Path.join(people_dir, "#{id_10}.md"), "---\nid: #{id_10}\nname: B\n---\n")
      File.write!(Path.join(tasks_dir, "#{id_15}.md"), "---\nid: #{id_15}\ntitle: C\n---\n")

      # Corrupt the counter
      File.write!(counter_file, "garbage")

      # Generate should recover and continue from max (15)
      assert {:ok, id} = Id.generate(workspace)
      assert Id.valid?(id)

      # Counter should now be 16
      assert File.read!(counter_file) == "16"
    end
  end

  describe "valid?/1" do
    test "accepts valid sqid" do
      assert Id.valid?("abcd1234")
    end

    test "accepts longer valid sqid" do
      assert Id.valid?("abcdefgh12345678")
    end

    test "rejects too-short string" do
      refute Id.valid?("abc1234")
    end

    test "rejects empty string" do
      refute Id.valid?("")
    end

    test "rejects uppercase characters" do
      refute Id.valid?("ABCD1234")
    end

    test "rejects special characters" do
      refute Id.valid?("abcd-123")
    end

    test "rejects non-binary input" do
      refute Id.valid?(12_345_678)
    end
  end
end
