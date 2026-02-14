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
    Logger.info("Starting Goodwizard application")

    children = [
      Goodwizard.Config,
      Goodwizard.Jido,
      Goodwizard.Messaging,
      Goodwizard.ShutdownHandler,
      {Task, &start_optional_channels/0}
    ]

    opts = [strategy: :rest_for_one, name: Goodwizard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp start_optional_channels do
    try do
      Goodwizard.Config.validate!()
    rescue
      e ->
        Logger.warning("Config validation failed: #{Exception.message(e)} — continuing startup")
    end

    if Goodwizard.Config.get(["channels", "telegram", "enabled"]) do
      Logger.info("Starting Telegram channel")

      case Supervisor.start_child(Goodwizard.Supervisor, %{
             id: Goodwizard.Channels.Telegram.Handler,
             start: {Goodwizard.Channels.Telegram.Handler, :start_link, [[]]},
             restart: :permanent
           }) do
        {:ok, _pid} ->
          Logger.info("Telegram channel started")

        {:error, {:already_started, _pid}} ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to start Telegram handler: #{inspect(reason)}")
      end
    end

    if Goodwizard.Config.get(["heartbeat", "enabled"]) do
      Logger.info("Starting Heartbeat")

      case Supervisor.start_child(Goodwizard.Supervisor, %{
             id: Goodwizard.Heartbeat,
             start: {Goodwizard.Heartbeat, :start_link, [[]]},
             restart: :permanent
           }) do
        {:ok, _pid} ->
          Logger.info("Heartbeat started")

        {:error, {:already_started, _pid}} ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to start Heartbeat: #{inspect(reason)}")
      end
    end
  end
end
