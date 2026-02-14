import Config

config :telegex,
  caller_adapter: {Finch, [receive_timeout: 60_000]}

config :goodwizard,
  config_path: "~/.goodwizard/config.toml"
