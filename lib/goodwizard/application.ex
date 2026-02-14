defmodule Goodwizard.Application do
  @moduledoc """
  OTP Application for Goodwizard.

  Starts the supervision tree: Config -> Jido -> Messaging (-> Telegram when enabled).
  Telegram is started post-init via a startup task that queries Config after it's alive.
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      Goodwizard.Config,
      Goodwizard.Jido,
      Goodwizard.Messaging,
      {Task, &start_optional_channels/0}
    ]

    opts = [strategy: :rest_for_one, name: Goodwizard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp start_optional_channels do
    if Goodwizard.Config.get(["channels", "telegram", "enabled"]) do
      case Supervisor.start_child(Goodwizard.Supervisor, %{
             id: Goodwizard.Channels.Telegram.Handler,
             start: {Goodwizard.Channels.Telegram.Handler, :start_link, [[]]},
             restart: :permanent
           }) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        {:error, reason} -> Logger.error("Failed to start Telegram handler: #{inspect(reason)}")
      end
    end
  end
end
