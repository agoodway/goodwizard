defmodule Goodwizard.KnowledgeBase.Legacy do
  @moduledoc """
  Handles legacy `brain` interface support during the knowledge base migration window.
  """

  require Logger

  @cutoff_paths [
    ["knowledge_base", "legacy_brain_aliases_until"],
    ["kb", "legacy_brain_aliases_until"],
    ["brain", "legacy_brain_aliases_until"]
  ]

  @doc """
  Runs a legacy-brain interface action with deprecation behavior.

  During the migration window, executes `fun` and emits a warning with the
  canonical replacement. After cutoff, returns an actionable error.
  """
  @spec run_legacy(map(), String.t(), String.t(), (-> {:ok, map()} | {:error, String.t()})) ::
          {:ok, map()} | {:error, String.t()}
  def run_legacy(context, legacy_name, replacement_name, fun) when is_function(fun, 0) do
    if legacy_brain_allowed?(context) do
      Logger.warning(
        "[KnowledgeBase] DEPRECATION: `#{legacy_name}` is a legacy brain interface. " <>
          "Use `#{replacement_name}` instead."
      )

      fun.()
    else
      {:error,
       "Legacy brain interface `#{legacy_name}` is no longer supported. " <>
         "Use `#{replacement_name}` (knowledge base / kb) instead."}
    end
  end

  @doc """
  Returns true when legacy `brain` aliases are still accepted.
  """
  @spec legacy_brain_allowed?(map()) :: boolean()
  def legacy_brain_allowed?(context \\ %{}) do
    case resolve_cutoff_date(context) do
      nil ->
        true

      cutoff ->
        Date.compare(Date.utc_today(), cutoff) != :gt
    end
  end

  defp resolve_cutoff_date(context) do
    context_cutoff =
      get_in(context, [:state, :legacy_brain_aliases_until]) ||
        get_in(context, [:state, "legacy_brain_aliases_until"])

    config_cutoff =
      Enum.find_value(@cutoff_paths, fn path ->
        Goodwizard.Config.get(path)
      end)

    parse_cutoff_date(context_cutoff || config_cutoff)
  end

  defp parse_cutoff_date(nil), do: nil
  defp parse_cutoff_date(""), do: nil

  defp parse_cutoff_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} ->
        date

      {:error, _reason} ->
        Logger.warning(
          "[KnowledgeBase] Invalid legacy cutoff date #{inspect(value)}; expected YYYY-MM-DD"
        )

        nil
    end
  end

  defp parse_cutoff_date(_), do: nil
end
