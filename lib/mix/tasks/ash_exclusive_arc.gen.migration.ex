defmodule Mix.Tasks.AshExclusiveArc.Gen.Migration do
  @shortdoc "Generates a constraint migration for an AshExclusiveArc resource."

  @moduledoc """
  Generates an `Ecto.Migration` containing the CHECK constraint(s) and partial
  unique indexes for the exclusive arcs on the given resource.

  Compares the resource's current arc definitions against a snapshot on disk
  to produce a clean diff between runs — analogous to
  `mix ash_postgres.generate_migrations`.

  ## Usage

      mix ash_exclusive_arc.gen.migration MyApp.CartItem --repo MyApp.Repo

  On the first run for a resource the task emits a migration that adds every
  arc constraint + index. On subsequent runs it diffs the current shape against
  the previous snapshot and emits a migration that drops the obsolete shape
  before adding the new one.

  ## Options

    * `--repo` — Ecto repo module. Required.
    * `--migrations-path` — directory for generated migrations.
      Defaults to `priv/<repo>/migrations`.
    * `--snapshot-path` — JSON snapshot path.
      Defaults to `priv/<repo>/exclusive_arc_snapshots/<table>.json`.
    * `--name` — override the migration file basename.
    * `--dry-run` — print the migration to stdout instead of writing.

  ## Snapshots

  Snapshots are pretty-printed JSON committed to version control. They contain
  only the inputs that affect generated SQL (table name, arc/reference shape,
  archival config). The generated migration embeds the resulting SQL inline,
  so `Ecto.Migrator` does not load the snapshot at run time.
  """

  use Mix.Task

  alias AshExclusiveArc.Migration.Generator

  @switches [
    repo: :string,
    migrations_path: :string,
    snapshot_path: :string,
    name: :string,
    dry_run: :boolean
  ]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.config")

    {opts, positional, _invalid} = OptionParser.parse(argv, switches: @switches)

    resource =
      case positional do
        [resource_str | _] -> resolve_module!(resource_str)
        [] -> Mix.raise("usage: mix ash_exclusive_arc.gen.migration <Resource> --repo <Repo>")
      end

    repo =
      case Keyword.get(opts, :repo) do
        nil -> Mix.raise("missing required --repo flag")
        str -> resolve_module!(str)
      end

    generate_opts =
      [repo: repo]
      |> maybe_put(:migrations_path, Keyword.get(opts, :migrations_path))
      |> maybe_put(:snapshot_path, Keyword.get(opts, :snapshot_path))
      |> maybe_put(:name, Keyword.get(opts, :name))

    result = Generator.generate(resource, generate_opts)

    if Keyword.get(opts, :dry_run, false) do
      print_dry_run(result)
    else
      commit(result)
    end
  end

  defp commit(%{status: :no_changes}) do
    Mix.shell().info("ash_exclusive_arc: no changes detected — no migration generated.")
  end

  defp commit(result) do
    :ok = Generator.write_result(result)

    Mix.shell().info("""
    ash_exclusive_arc: wrote migration #{relative_path(result.migration_path)}
    ash_exclusive_arc: wrote snapshot  #{relative_path(result.snapshot_path)}
    """)
  end

  defp print_dry_run(%{status: :no_changes}) do
    Mix.shell().info("ash_exclusive_arc: no changes detected.")
  end

  defp print_dry_run(result) do
    Mix.shell().info("""
    -- migration: #{result.migration_path}
    #{result.migration_contents}
    -- snapshot:  #{result.snapshot_path}
    """)
  end

  defp resolve_module!(str) do
    module = if String.starts_with?(str, "Elixir."), do: str, else: "Elixir." <> str

    case Code.ensure_compiled(String.to_atom(module)) do
      {:module, mod} -> mod
      {:error, reason} -> Mix.raise("could not load module #{str}: #{inspect(reason)}")
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp relative_path(path) do
    cwd = File.cwd!()
    Path.relative_to(path, cwd)
  end
end
