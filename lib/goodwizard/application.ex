defmodule Goodwizard.Application do
  @moduledoc """
  OTP Application for Goodwizard.

  Starts the supervision tree: Config -> Jido -> Messaging.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Goodwizard.Config,
      Goodwizard.Jido,
      Goodwizard.Messaging
    ]

    opts = [strategy: :rest_for_one, name: Goodwizard.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
