import Config

Dotenvy.source!([".env", System.get_env()])

config :telegex, token: Dotenvy.env!("TELEGRAM_BOT_TOKEN", :string)
