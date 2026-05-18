defmodule AshExclusiveArc.Migration.Generator do
  @moduledoc """
  Pure-Elixir engine for `mix ash_exclusive_arc.gen.migration`.

  Builds an `AshExclusiveArc.Snapshot` from a resource, compares it against the
  on-disk snapshot for the same table, and produces an `Ecto.Migration` file
  whose `up/0` and `down/0` embed the resulting CHECK + partial-unique-index
  SQL inline (so the migration is self-contained — `Ecto.Migrator` does not
  need to load the snapshot at run time).

  Results are returned as a `Result` struct so callers (the mix task, tests,
  `--dry-run`) can inspect what *would* be written before committing it to
  disk via `write_result/1`.
  """

  alias AshExclusiveArc.Snapshot

  defmodule Result do
    @moduledoc false

    @type status :: :initial | :update | :no_changes

    defstruct [
      :status,
      :migration_path,
      :migration_contents,
      :snapshot_path,
      :new_snapshot,
      :old_snapshot,
      :diff
    ]

    @type t :: %__MODULE__{
            status: status(),
            migration_path: Path.t() | nil,
            migration_contents: String.t() | nil,
            snapshot_path: Path.t(),
            new_snapshot: Snapshot.t(),
            old_snapshot: Snapshot.t() | nil,
            diff: term()
          }
  end

  @doc """
  Builds a migration result for `resource`.

  ## Options

    * `:repo` *(required)* — the Ecto repo module the migration belongs to.
    * `:migrations_path` — directory to place the migration in. Defaults to
      `priv/<repo>/migrations`.
    * `:snapshot_path` — path to read/write the snapshot. Defaults to
      `Snapshot.default_path(repo, table)`.
    * `:name` — override the migration's basename (default `add_exclusive_arcs_<table>`
      on initial, `update_exclusive_arcs_<table>` thereafter).
    * `:timestamp` — fixed `YYYYMMDDHHMMSS` string. Mostly for tests.
  """
  @spec generate(Ash.Resource.t(), keyword()) :: Result.t()
  def generate(resource, opts) do
    repo = Keyword.fetch!(opts, :repo)
    new_snapshot = Snapshot.build(resource)

    snapshot_path =
      Keyword.get(opts, :snapshot_path, Snapshot.default_path(repo, new_snapshot.table))

    migrations_path = Keyword.get(opts, :migrations_path, default_migrations_path(repo))

    old_snapshot =
      case Snapshot.read(snapshot_path) do
        {:ok, snapshot} -> snapshot
        {:error, :enoent} -> nil
        {:error, reason} -> raise "Could not read snapshot #{snapshot_path}: #{inspect(reason)}"
      end

    diff = Snapshot.diff(old_snapshot, new_snapshot)
    status = status_for(old_snapshot, diff)

    build_result(status, %{
      old_snapshot: old_snapshot,
      new_snapshot: new_snapshot,
      diff: diff,
      snapshot_path: snapshot_path,
      migrations_path: migrations_path,
      repo: repo,
      name: Keyword.get(opts, :name),
      timestamp: Keyword.get(opts, :timestamp, timestamp())
    })
  end

  @doc """
  Persists a generator result to disk: writes the migration file (when present)
  and the updated snapshot. A `:no_changes` result is a no-op.
  """
  @spec write_result(Result.t()) :: :ok | {:error, term()}
  def write_result(%Result{status: :no_changes}), do: :ok

  def write_result(%Result{} = result) do
    with :ok <- File.mkdir_p(Path.dirname(result.migration_path)),
         :ok <- File.write(result.migration_path, result.migration_contents),
         :ok <- Snapshot.write(result.snapshot_path, result.new_snapshot) do
      :ok
    end
  end

  @doc false
  @spec module_name_for(module(), String.t()) :: String.t()
  def module_name_for(repo, name) when is_binary(name) do
    "#{inspect(repo)}.Migrations.#{Macro.camelize(name)}"
  end

  # ---------- internals ----------

  defp status_for(nil, _diff), do: :initial
  defp status_for(_old, :no_changes), do: :no_changes
  defp status_for(_old, _diff), do: :update

  defp build_result(:no_changes, ctx) do
    %Result{
      status: :no_changes,
      migration_path: nil,
      migration_contents: nil,
      snapshot_path: ctx.snapshot_path,
      new_snapshot: ctx.new_snapshot,
      old_snapshot: ctx.old_snapshot,
      diff: ctx.diff
    }
  end

  defp build_result(status, ctx) do
    name = ctx.name || default_name(status, ctx.new_snapshot.table)
    filename = "#{ctx.timestamp}_#{name}.exs"
    migration_path = Path.join(ctx.migrations_path, filename)

    up_sql = up_sql_for(status, ctx)
    down_sql = down_sql_for(status, ctx)

    contents = migration_file(ctx.repo, name, up_sql, down_sql)

    %Result{
      status: status,
      migration_path: migration_path,
      migration_contents: contents,
      snapshot_path: ctx.snapshot_path,
      new_snapshot: ctx.new_snapshot,
      old_snapshot: ctx.old_snapshot,
      diff: ctx.diff
    }
  end

  defp default_name(:initial, table), do: "add_exclusive_arcs_#{table}"
  defp default_name(:update, table), do: "update_exclusive_arcs_#{table}"

  defp up_sql_for(:initial, ctx), do: Snapshot.up_statements(ctx.new_snapshot)

  defp up_sql_for(:update, ctx) do
    changed_names = changed_arc_names(ctx.diff)

    drops =
      ctx.diff.removed
      |> Enum.concat(arcs_in(ctx.old_snapshot, changed_names))
      |> Enum.flat_map(&Snapshot.down_statements(ctx.old_snapshot, &1.name))

    adds =
      ctx.diff.added
      |> Enum.concat(arcs_in(ctx.new_snapshot, changed_names))
      |> Enum.flat_map(&Snapshot.up_statements(ctx.new_snapshot, &1.name))

    drops ++ adds
  end

  defp down_sql_for(:initial, ctx), do: Snapshot.down_statements(ctx.new_snapshot)

  defp down_sql_for(:update, ctx) do
    changed_names = changed_arc_names(ctx.diff)

    drops =
      ctx.diff.added
      |> Enum.concat(arcs_in(ctx.new_snapshot, changed_names))
      |> Enum.flat_map(&Snapshot.down_statements(ctx.new_snapshot, &1.name))

    adds =
      ctx.diff.removed
      |> Enum.concat(arcs_in(ctx.old_snapshot, changed_names))
      |> Enum.flat_map(&Snapshot.up_statements(ctx.old_snapshot, &1.name))

    drops ++ adds
  end

  defp changed_arc_names(%{changed: changed}), do: Enum.map(changed, & &1.name)
  defp changed_arc_names(_), do: []

  defp arcs_in(snapshot, names) do
    Enum.filter(snapshot.arcs, &(&1.name in names))
  end

  defp migration_file(repo, name, up_statements, down_statements) do
    module = module_name_for(repo, name)

    """
    defmodule #{module} do
      @moduledoc false
      use Ecto.Migration

      def up do
    #{indent_statements(up_statements)}
      end

      def down do
    #{indent_statements(down_statements)}
      end
    end
    """
  end

  defp indent_statements([]), do: "    :ok"

  defp indent_statements(statements) do
    statements
    |> Enum.map(&"    execute(#{inspect(&1)})")
    |> Enum.join("\n\n")
  end

  defp default_migrations_path(repo) do
    repo_segment = repo |> Module.split() |> List.last() |> Macro.underscore()
    Path.join(["priv", repo_segment, "migrations"])
  end

  defp timestamp do
    {{y, mo, d}, {h, mi, s}} = :calendar.universal_time()
    :io_lib.format(~c"~4..0B~2..0B~2..0B~2..0B~2..0B~2..0B", [y, mo, d, h, mi, s]) |> to_string()
  end
end
