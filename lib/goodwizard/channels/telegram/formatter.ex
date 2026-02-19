defmodule Goodwizard.Channels.Telegram.Formatter do
  @moduledoc """
  Converts markdown-like content into Telegram-compatible HTML.

  This module is intentionally introduced as a dedicated boundary so Telegram
  formatting can evolve independently from message generation.
  """

  @doc """
  Converts text into Telegram-safe HTML.

  Subsequent tasks will expand this function with full markdown conversion.
  """
  @spec to_telegram_html(String.t()) :: String.t()
  def to_telegram_html(text) when is_binary(text), do: text
end
