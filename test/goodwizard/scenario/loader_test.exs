defmodule Goodwizard.Scenario.LoaderTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Scenario.Loader

  setup do
    scenarios_dir =
      Path.join(
        System.tmp_dir!(),
        "scenario_loader_#{System.unique_integer([:positive, :monotonic])}"
      )

    File.mkdir_p!(scenarios_dir)
    on_exit(fn -> File.rm_rf!(scenarios_dir) end)

    opts = [scenarios_dir: scenarios_dir]
    %{scenarios_dir: scenarios_dir, opts: opts}
  end

  test "load/2 parses query/setup steps and assertions", %{
    scenarios_dir: scenarios_dir,
    opts: opts
  } do
    File.write!(
      Path.join(scenarios_dir, "sample.toml"),
      """
      description = "sample scenario"

      [[steps]]
      type = "query"
      query = "Hello"

      [[steps]]
      type = "setup"
      action = "write_file"
      path = "notes.md"
      content = "hello"

      [[assertions]]
      type = "response_contains"
      step_index = 0
      value = "hello"
      """
    )

    assert {:ok, scenario} = Loader.load("sample", opts)
    assert scenario.name == "sample"
    assert scenario.description == "sample scenario"
    assert length(scenario.steps) == 2
    assert Enum.at(scenario.steps, 0).type == :query
    assert Enum.at(scenario.steps, 1).type == :setup
    assert Enum.at(scenario.assertions, 0).type == "response_contains"
  end

  test "list/1 includes names and descriptions", %{scenarios_dir: scenarios_dir, opts: opts} do
    File.write!(
      Path.join(scenarios_dir, "alpha.toml"),
      """
      description = "Alpha scenario"
      [[steps]]
      type = "query"
      query = "hello"
      """
    )

    File.write!(
      Path.join(scenarios_dir, "beta.toml"),
      """
      description = "Beta scenario"
      [[steps]]
      type = "query"
      query = "world"
      """
    )

    assert {:ok, scenarios} = Loader.list(opts)
    assert Enum.map(scenarios, & &1.name) == ["alpha", "beta"]
    assert Enum.at(scenarios, 0).description == "Alpha scenario"
    assert Enum.at(scenarios, 1).description == "Beta scenario"
  end

  test "load/2 returns not_found with available scenarios", %{
    scenarios_dir: scenarios_dir,
    opts: opts
  } do
    File.write!(
      Path.join(scenarios_dir, "known.toml"),
      """
      [[steps]]
      type = "query"
      query = "hello"
      """
    )

    assert {:error, {:not_found, ["known"]}} = Loader.load("missing", opts)
  end

  test "load/2 rejects invalid path names", %{opts: opts} do
    assert {:error, :invalid_name} = Loader.load("../secrets", opts)
  end

  test "load/2 returns decode error for invalid TOML", %{scenarios_dir: scenarios_dir, opts: opts} do
    File.write!(Path.join(scenarios_dir, "broken.toml"), "this is not valid toml")
    assert {:error, _reason} = Loader.load("broken", opts)
  end
end
