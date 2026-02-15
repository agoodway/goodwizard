import Config

config :telegex,
  caller_adapter: {Finch, [receive_timeout: 60_000]}

config :goodwizard,
  config_path: "config.toml"

config :goodwizard, Goodwizard.Cache,
  gc_interval: :timer.hours(12),
  max_size: 100_000,
  allocated_memory: 100_000_000
