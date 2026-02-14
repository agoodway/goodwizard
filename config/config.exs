import Config

config :telegex,
  caller_adapter: {Telegex.Caller.FinchAdapter, [receive_timeout: 60_000]}

config :goodwizard,
  config_path: "~/.goodwizard/config.toml"
