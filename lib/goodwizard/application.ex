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
    maybe_add_file_logger()

    Logger.info("Starting Goodwizard application")

    Goodwizard.Telemetry.attach()

    children = [
      Goodwizard.Config,
      Goodwizard.Cache,
      Goodwizard.Jido,
      Goodwizard.Messaging,
      Goodwizard.ShutdownHandler,
      {Task, &start_optional_channels/0}
    ]

    opts = [strategy: :rest_for_one, name: Goodwizard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  if Mix.env() == :dev do
    defp maybe_add_file_logger do
      log_dir = Path.join(File.cwd!(), "log")
      File.mkdir_p!(log_dir)

      :logger.add_handler(:file_log, :logger_std_h, %{
        config: %{file: String.to_charlist(Path.join(log_dir, "dev.log"))},
        formatter: Logger.Formatter.new()
      })
    end
  else
    defp maybe_add_file_logger, do: :ok
  end

  defp start_optional_channels do
    try do
      Goodwizard.Config.validate!()
    rescue
      e ->
        Logger.warning("Config validation failed: #{Exception.message(e)} — continuing startup")
    end

    maybe_start_telegram()
    maybe_start_heartbeat()
  end

  defp maybe_start_telegram do
    if Goodwizard.Config.get(["channels", "telegram", "enabled"]) do
      start_optional_child(
        Goodwizard.Channels.Telegram.Handler,
        "Telegram channel"
      )
    end
  end

  defp maybe_start_heartbeat do
    if Goodwizard.Config.get(["heartbeat", "enabled"]) do
      start_optional_child(Goodwizard.Heartbeat, "Heartbeat")
    end
  end

  defp start_optional_child(module, label) do
    Logger.info("Starting #{label}")

    case Supervisor.start_child(Goodwizard.Supervisor, %{
           id: module,
           start: {module, :start_link, [[]]},
           restart: :permanent
         }) do
      {:ok, _pid} ->
        Logger.info("#{label} started")

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to start #{label}: #{inspect(reason)}")
    end
  end
end
