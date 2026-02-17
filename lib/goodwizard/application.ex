defmodule Goodwizard.Application do
  @moduledoc """
  OTP Application for Goodwizard.

  Starts the supervision tree: Config -> Jido -> Messaging (-> Telegram when enabled).
  Telegram is started post-init via a startup task that queries Config after it's alive.
  """
  use Application
  require Logger

  alias Goodwizard.Brain.ToolGenerator

  @impl true
  def start(_type, _args) do
    maybe_add_file_logger()

    Logger.info("Starting Goodwizard application")

    Goodwizard.Telemetry.attach()

    children = [
      Goodwizard.Config,
      Goodwizard.Cache,
      Goodwizard.BrowserSessionStore,
      Goodwizard.Browser.Serializer,
      Goodwizard.Scheduling.CronRegistry,
      Goodwizard.Scheduling.OneShotRegistry,
      Goodwizard.Jido,
      Supervisor.child_spec({Task, &generate_brain_tools/0}, id: :brain_tools),
      Goodwizard.Messaging,
      Goodwizard.ShutdownHandler,
      {Task, &start_optional_channels/0}
    ]

    opts = [strategy: :rest_for_one, name: Goodwizard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_add_file_logger do
    log_dir = Path.join(File.cwd!(), "logs")
    File.mkdir_p!(log_dir)
    log_file = "#{Mix.env()}.log"

    :logger.add_handler(:file_log, :logger_std_h, %{
      config: %{file: String.to_charlist(Path.join(log_dir, log_file))},
      formatter: Logger.Formatter.new()
    })
  end

  defp generate_brain_tools do
    workspace = Goodwizard.Config.workspace()
    {:ok, modules} = ToolGenerator.generate_all(workspace)
    Logger.info("Generated #{length(modules)} brain tools at startup")
  rescue
    e ->
      Logger.warning("Brain tool generation error: #{Exception.message(e)}")
  end

  defp start_optional_channels do
    try do
      Goodwizard.Config.validate!()
    rescue
      e ->
        Logger.warning("Config validation failed: #{Exception.message(e)} — continuing startup")
    end

    reload_cron_jobs()
    reload_oneshot_jobs()
    maybe_start_telegram()
    maybe_start_heartbeat()
  end

  defp reload_cron_jobs do
    case Goodwizard.Scheduling.CronLoader.reload() do
      {:ok, count} when count > 0 ->
        Logger.info("Reloaded #{count} persisted cron job(s)")

      {:ok, 0} ->
        :ok

      {:error, reason} ->
        Logger.warning("Cron job reload failed: #{inspect(reason)} — continuing startup")
    end
  rescue
    e ->
      Logger.warning("Cron job reload error: #{Exception.message(e)} — continuing startup")
  end

  defp reload_oneshot_jobs do
    case Goodwizard.Scheduling.OneShotLoader.reload() do
      {:ok, count} when count > 0 ->
        Logger.info("Reloaded #{count} persisted one-shot job(s)")

      {:ok, 0} ->
        :ok

      {:error, reason} ->
        Logger.warning("One-shot job reload failed: #{inspect(reason)} — continuing startup")
    end
  rescue
    e ->
      Logger.warning("One-shot job reload error: #{Exception.message(e)} — continuing startup")
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
