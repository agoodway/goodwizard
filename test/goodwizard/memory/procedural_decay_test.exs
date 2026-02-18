defmodule Goodwizard.Memory.ProceduralDecayTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Memory.Entry
  alias Goodwizard.Memory.Procedural

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "procedural_decay_test_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    %{memory_dir: tmp_dir}
  end

  defp create_procedure(memory_dir, opts) do
    confidence = Keyword.get(opts, :confidence, "medium")
    type = Keyword.get(opts, :type, "workflow")
    source = Keyword.get(opts, :source, "learned")
    days_ago_used = Keyword.get(opts, :days_ago_used, nil)
    days_ago_created = Keyword.get(opts, :days_ago_created, 0)

    frontmatter = %{
      "type" => type,
      "summary" => Keyword.get(opts, :summary, "Test procedure"),
      "source" => source,
      "confidence" => confidence,
      "tags" => Keyword.get(opts, :tags, [])
    }

    body = "## When to apply\n\nTest\n\n## Steps\n\nDo the thing\n\n## Notes\n\nNone"

    {:ok, fm} = Procedural.create(memory_dir, frontmatter, body)

    # Override timestamps by rewriting the file
    dir = Path.join(memory_dir, "procedural")
    path = Path.join(dir, "#{fm["id"]}.md")

    created_at =
      DateTime.utc_now()
      |> DateTime.add(-days_ago_created, :day)
      |> DateTime.to_iso8601()

    # Set updated_at to the oldest relevant timestamp so the idempotency guard
    # (which skips procedures updated today) does not interfere with tests.
    # Use last_used date if available, otherwise created_at.
    updated_at =
      if days_ago_used do
        DateTime.utc_now()
        |> DateTime.add(-days_ago_used, :day)
        |> DateTime.to_iso8601()
      else
        created_at
      end

    last_used =
      if days_ago_used do
        DateTime.utc_now()
        |> DateTime.add(-days_ago_used, :day)
        |> DateTime.to_iso8601()
      else
        nil
      end

    updated_fm =
      fm
      |> Map.put("created_at", created_at)
      |> Map.put("updated_at", updated_at)
      |> Map.put("last_used", last_used)

    content = Entry.serialize(updated_fm, body)
    File.write!(path, content)

    fm["id"]
  end

  describe "recently used procedures not demoted" do
    test "procedure used within decay_days is unchanged", %{memory_dir: dir} do
      id = create_procedure(dir, confidence: "high", days_ago_used: 30)

      assert {:ok, result} = Procedural.decay_unused(dir, decay_days: 60)
      assert result.unchanged >= 1
      assert result.demoted == 0

      {:ok, {fm, _body}} = Procedural.read(dir, id)
      assert fm["confidence"] == "high"
    end
  end

  describe "high-confidence procedure demoted to medium" do
    test "high confidence demoted after decay_days", %{memory_dir: dir} do
      id = create_procedure(dir, confidence: "high", days_ago_used: 90)

      assert {:ok, result} = Procedural.decay_unused(dir, decay_days: 60)
      assert result.demoted >= 1

      {:ok, {fm, _body}} = Procedural.read(dir, id)
      assert fm["confidence"] == "medium"
    end
  end

  describe "medium-confidence procedure demoted to low" do
    test "medium confidence demoted after decay_days", %{memory_dir: dir} do
      id = create_procedure(dir, confidence: "medium", days_ago_used: 90)

      assert {:ok, result} = Procedural.decay_unused(dir, decay_days: 60)
      assert result.demoted >= 1

      {:ok, {fm, _body}} = Procedural.read(dir, id)
      assert fm["confidence"] == "low"
    end
  end

  describe "low-confidence procedure deleted after 120+ days" do
    test "low confidence deleted after archive_days", %{memory_dir: dir} do
      id = create_procedure(dir, confidence: "low", days_ago_used: 150)

      assert {:ok, result} = Procedural.decay_unused(dir, archive_days: 120)
      assert result.deleted >= 1

      assert {:error, :not_found} = Procedural.read(dir, id)
    end
  end

  describe "procedure with nil last_used handled correctly" do
    test "nil last_used with old created_at and low confidence is deleted", %{memory_dir: dir} do
      id = create_procedure(dir, confidence: "low", days_ago_created: 150)

      assert {:ok, result} = Procedural.decay_unused(dir, archive_days: 120)
      assert result.deleted >= 1

      assert {:error, :not_found} = Procedural.read(dir, id)
    end

    test "nil last_used with high confidence is demoted", %{memory_dir: dir} do
      id = create_procedure(dir, confidence: "high")

      # Override to have no last_used and old timestamps
      dir_path = Path.join(dir, "procedural")
      path = Path.join(dir_path, "#{id}.md")
      {:ok, content} = File.read(path)
      {:ok, {fm, body}} = Entry.parse(content)

      old_ts =
        DateTime.utc_now()
        |> DateTime.add(-90, :day)
        |> DateTime.to_iso8601()

      updated =
        fm
        |> Map.put("last_used", nil)
        |> Map.put("created_at", old_ts)
        |> Map.put("updated_at", old_ts)

      File.write!(path, Entry.serialize(updated, body))

      assert {:ok, result} = Procedural.decay_unused(dir, decay_days: 60)
      assert result.demoted >= 1

      {:ok, {updated_fm, _body}} = Procedural.read(dir, id)
      assert updated_fm["confidence"] == "medium"
    end
  end

  describe "decay is idempotent" do
    test "running twice does not double-demote", %{memory_dir: dir} do
      id = create_procedure(dir, confidence: "high", days_ago_used: 90)

      assert {:ok, result1} = Procedural.decay_unused(dir, decay_days: 60)
      assert result1.demoted >= 1

      {:ok, {fm1, _body}} = Procedural.read(dir, id)
      assert fm1["confidence"] == "medium"

      # Second run: updated_at is now today, so idempotency guard skips it
      assert {:ok, result2} = Procedural.decay_unused(dir, decay_days: 60)
      assert result2.demoted == 0

      {:ok, {fm2, _body}} = Procedural.read(dir, id)
      assert fm2["confidence"] == "medium"
    end
  end
end
