defmodule Goodwizard.Jido do
  @moduledoc """
  Jido v2 instance module for Goodwizard.

  Manages agent lifecycle, registry, and task supervision.
  """
  use Jido, otp_app: :goodwizard
end
