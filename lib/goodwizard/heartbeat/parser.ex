defmodule Goodwizard.Heartbeat.Parser do
  @moduledoc """
  Parses HEARTBEAT.md content to detect and extract structured task-list items.

  Supports markdown checkbox syntax (`- [ ] text` and `- [x] text`). When any
  line matches the task-list pattern, the file is treated as structured and
  individual check items are extracted. Plain text files pass through unchanged.
  """

  @task_list_regex ~r/^- \[([ x])\] (.+)$/m

  @doc """
  Returns `true` if the content contains any markdown task-list lines.
  """
  @spec structured?(String.t()) :: boolean()
  def structured?(content) do
    Regex.match?(@task_list_regex, content)
  end

  @doc """
  Parses content into structured checks or plain text.

  Returns `{:structured, checks}` where `checks` is a list of
  `%{index: integer, text: string, checked: boolean}` maps, or
  `{:plain, content}` if no task-list lines are found.
  """
  @spec parse(String.t()) ::
          {:structured, [%{index: pos_integer(), text: String.t(), checked: boolean()}]}
          | {:plain, String.t()}
  def parse(content) do
    matches = Regex.scan(@task_list_regex, content)

    case matches do
      [] ->
        {:plain, content}

      _ ->
        checks =
          matches
          |> Enum.with_index(1)
          |> Enum.map(fn {[_full, status, text], index} ->
            %{index: index, text: String.trim(text), checked: status == "x"}
          end)

        {:structured, checks}
    end
  end

  @doc """
  Matches a single line against the task-list pattern.

  Returns `{:ok, text}` if the line is a check item, or `:nomatch` otherwise.
  """
  @spec match_check_line(String.t()) :: {:ok, String.t()} | :nomatch
  def match_check_line(line) do
    case Regex.run(@task_list_regex, line) do
      [_, _status, text] -> {:ok, text}
      _ -> :nomatch
    end
  end

  @doc """
  Builds a numbered instruction prompt from a list of check maps.

  ## Example

      iex> build_prompt([%{index: 1, text: "Check inbox"}, %{index: 2, text: "Review calendar"}])
      "Process each of the following awareness checks and report on each:\\n1. Check inbox\\n2. Review calendar"
  """
  @spec build_prompt([%{index: pos_integer(), text: String.t()}]) :: String.t()
  def build_prompt(checks) do
    items =
      checks
      |> Enum.map(fn %{index: i, text: text} -> "#{i}. #{text}" end)
      |> Enum.join("\n")

    "Process each of the following awareness checks and report on each:\n#{items}"
  end
end
