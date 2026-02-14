defmodule Goodwizard.MixProject do
  use Mix.Project

  def project do
    [
      app: :goodwizard,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Goodwizard.Application, []}
    ]
  end

  defp deps do
    [
      {:jido, "~> 2.0.0-rc", override: true},
      {:jido_ai, github: "agentjido/jido_ai", override: true},
      {:jido_character, github: "agentjido/jido_character"},
      {:jido_browser, "~> 0.8", override: true},
      {:jido_messaging, github: "agentjido/jido_messaging"},
      {:telegex, "~> 1.8"},
      {:finch, "~> 0.18"},
      {:plug, "~> 1.15"},
      {:plug_cowboy, "~> 2.7"},
      {:toml, "~> 0.7"},
      {:jason, "~> 1.4"}
    ]
  end
end
