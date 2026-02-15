defmodule Goodwizard.Actions.Brain.Helpers do
  @moduledoc """
  Shared helpers for brain action modules.
  """

  @doc """
  Formats error reasons into safe, user-friendly messages.

  Returns specific messages for known error atoms and a generic
  fallback for unexpected errors to avoid leaking internal details.
  """
  @spec format_error(term()) :: String.t()
  def format_error(reason) when is_binary(reason), do: reason
  def format_error(:not_found), do: "Entity not found"
  def format_error(:path_traversal), do: "Invalid path"
  def format_error(:body_too_large), do: "Body exceeds maximum size"
  def format_error(:update_locked), do: "Entity is locked by another operation"
  def format_error(:enoent), do: "File not found"
  def format_error(:eacces), do: "Permission denied"
  def format_error({:duplicate_id, _id}), do: "Duplicate entity ID"
  def format_error({:parse_error, _file, _reason}), do: "Failed to parse entity file"
  def format_error({:schema_resolution_error, _msg}), do: "Schema resolution failed"
  def format_error({:validation, errors}) when is_list(errors), do: "Validation failed"
  def format_error(_reason), do: "An unexpected error occurred"
end
