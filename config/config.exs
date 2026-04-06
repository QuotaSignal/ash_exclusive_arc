import Config

if Mix.env() == :test do
  config :ash_exclusive_arc, ash_domains: [AshExclusiveArc.Test.Domain]

  config :ash_exclusive_arc,
    ecto_repos: [AshExclusiveArc.TestRepo]

  config :ash, :validate_domain_resource_inclusion?, false
  config :ash, :validate_domain_config_inclusion?, false
  config :logger, level: :warning

  config :ash_exclusive_arc, AshExclusiveArc.TestRepo,
    username: "postgres",
    password: "postgres",
    database: "ash_exclusive_arc_test",
    hostname: "localhost",
    pool: Ecto.Adapters.SQL.Sandbox
end

if Mix.env() == :dev do
  config :git_ops,
    mix_project: AshExclusiveArc.MixProject,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/britton-jb/ash_exclusive_arc",
    manage_mix_version?: true,
    manage_readme_version: [
      "README.md",
      "documentation/tutorials/get-started.md"
    ],
    version_tag_prefix: "v"
end
