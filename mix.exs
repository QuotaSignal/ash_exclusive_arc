defmodule AshExclusiveArc.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description """
  An Ash extension implementing the exclusive belongs-to (exclusive arc) pattern
  for referential-integrity-safe polymorphic relationships.
  """

  def project do
    [
      app: :ash_exclusive_arc,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: @description,
      package: package(),
      docs: &docs/0,
      aliases: aliases(),
      preferred_cli_env: [
        "test.create": :test,
        "test.migrate": :test
      ],
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      dialyzer: [plt_add_apps: [:mix, :ex_unit]],
      source_url: "https://github.com/britton-jb/ash_exclusive_arc",
      homepage_url: "https://github.com/britton-jb/ash_exclusive_arc"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ash, ash_version("~> 3.0")},
      # dev/test
      {:ash_postgres, "~> 2.3", only: [:dev, :test]},
      {:simple_sat, "~> 0.1.0", only: [:dev, :test]},
      {:igniter, "~> 0.5", only: [:dev, :test]},
      {:ex_doc, "~> 0.37-rc", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.14", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.5", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      maintainers: ["Britton Broderick"],
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG* documentation),
      links: %{
        "GitHub" => "https://github.com/britton-jb/ash_exclusive_arc",
        "Changelog" => "https://github.com/britton-jb/ash_exclusive_arc/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        {"README.md", title: "Home"},
        "documentation/tutorials/get-started.md",
        "documentation/topics/how-it-works.md",
        "documentation/topics/referential-integrity.md",
        {"documentation/dsls/DSL-AshExclusiveArc.Resource.md",
         search_data: Spark.Docs.search_data_for(AshExclusiveArc.Resource)},
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        Topics: ~r'documentation/topics',
        DSLs: ~r'documentation/dsls'
      ],
      groups_for_modules: [
        Extension: [
          AshExclusiveArc,
          AshExclusiveArc.Resource
        ],
        Introspection: [
          AshExclusiveArc.Resource.Info
        ],
        Migration: [
          AshExclusiveArc.Migration
        ]
      ]
    ]
  end

  defp aliases do
    [
      "test.create": "ash_postgres.create",
      "test.migrate": "ash_postgres.migrate",
      sobelow: "sobelow --skip -i Config.Secrets",
      credo: "credo --strict",
      docs: ["spark.cheat_sheets", "docs", "spark.replace_doc_links"],
      "spark.formatter": "spark.formatter --extensions AshExclusiveArc.Resource",
      "spark.cheat_sheets": "spark.cheat_sheets --extensions AshExclusiveArc.Resource"
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash", override: true]
      "main" -> [git: "https://github.com/ash-project/ash.git", override: true]
      version -> "~> #{version}"
    end
  end
end
