defmodule Goodwizard.MixProject do
  use Mix.Project

  def project do
    [
      app: :goodwizard,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit, :mix],
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [check: :test, precommit: :test]
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
      {:jido_ai, github: "agentjido/jido_ai", ref: "2e42e09", override: true},
      {:jido_character, github: "agentjido/jido_character", ref: "20ae4ef"},
      {:jido_browser, "~> 0.8", override: true},
      {:jido_messaging, github: "agentjido/jido_messaging", ref: "96e62c7"},
      {:telegex, "~> 1.8"},
      {:finch, "~> 0.18"},
      {:plug, "~> 1.15"},
      {:plug_cowboy, "~> 2.7"},
      {:toml, "~> 0.7"},
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.9"},
      {:dotenvy, "~> 1.1"},

      # Code Quality (dev/test only)
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.21", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      check: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format --check-formatted",
        "credo --strict",
        "doctor",
        "dialyzer",
        "test"
      ],
      precommit: ["check"]
    ]
  end
end
