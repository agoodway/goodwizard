defmodule Goodwizard.ErrorFormatter do
  @moduledoc "Converts raw error terms into user-friendly messages."

  @doc "Returns a user-friendly string for the given error reason."
  @spec format(term()) :: String.t()

  # -- ReqLLM API errors --

  # Usage limit / rate limit errors (status 400/429)
  def format(%ReqLLM.Error.API.Request{reason: reason, status: status})
      when status in [400, 429] and is_binary(reason) do
    cond do
      String.contains?(reason, "usage limit") ->
        case Regex.run(~r/access on (.+)/, reason) do
          [_, date] -> "I've hit my API usage limit. Access resets on #{date}."
          _ -> "I've hit my API usage limit. Please try again later."
        end

      String.contains?(reason, "rate limit") or String.contains?(reason, "Rate Limited") ->
        "I'm being rate-limited by my AI provider. Please wait a moment and try again."

      true ->
        "Request rejected by AI provider: #{reason}"
    end
  end

  # Auth errors
  def format(%ReqLLM.Error.API.Request{status: status})
      when status in [401, 403] do
    "I'm having trouble authenticating with my AI provider. Please check the API key configuration."
  end

  # Server errors
  def format(%ReqLLM.Error.API.Request{status: status})
      when is_integer(status) and status >= 500 do
    "My AI provider is experiencing issues (HTTP #{status}). Please try again shortly."
  end

  # Generic API request error with reason text
  def format(%ReqLLM.Error.API.Request{reason: reason}) when is_binary(reason) do
    "AI provider error: #{reason}"
  end

  # Response parsing errors
  def format(%ReqLLM.Error.API.Response{}) do
    "I received an unexpected response from my AI provider. Please try again."
  end

  # JSON decode errors
  def format(%ReqLLM.Error.API.JSONDecode{}) do
    "I received a malformed response from my AI provider. Please try again."
  end

  # Stream errors
  def format(%ReqLLM.Error.API.Stream{reason: reason}) when is_binary(reason) do
    "Streaming error: #{reason}"
  end

  # -- Jido/executor error maps --

  def format(%{error: error, type: :execution_error}) when is_binary(error) do
    format_from_string(error)
  end

  def format(%{error: error, type: :exception}) when is_binary(error) do
    format_from_string(error)
  end

  # -- Simple types --

  def format(:timeout), do: "The request timed out. Please try again."

  def format(reason) when is_binary(reason), do: format_from_string(reason)

  def format(reason) when is_atom(reason) do
    reason |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  # Any exception implementing Exception protocol
  def format(reason) when is_exception(reason) do
    format_from_string(Exception.message(reason))
  end

  def format(_reason), do: "An unexpected error occurred. Please try again."

  # -- Helpers --

  defp format_from_string(msg) do
    cond do
      String.contains?(msg, "usage limit") ->
        case Regex.run(~r/access on (.+)/, msg) do
          [_, date] -> "I've hit my API usage limit. Access resets on #{date}."
          _ -> "I've hit my API usage limit. Please try again later."
        end

      String.contains?(msg, "rate limit") ->
        "I'm being rate-limited by my AI provider. Please wait a moment and try again."

      String.contains?(msg, "timed out") ->
        "The request timed out. Please try again."

      true ->
        msg
    end
  end
end
