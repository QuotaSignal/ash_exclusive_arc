defmodule AshExclusiveArc.Snapshot do
  @moduledoc """
  Resource snapshots for `mix ash_exclusive_arc.gen.migration`.

  A snapshot captures the inputs that affect generated CHECK / partial-unique-index
  SQL for an exclusive-arc resource: the table name, every arc's
  `referential_integrity` and archival configuration, and every reference's
  attribute name and destination.

  Snapshots are pretty-printed JSON so that adding or removing a branch from an
  arc produces a clean diff in version control. They are written to disk by the
  generator task and read back on the next run to compute the migration delta.

  The migration generator embeds SQL directly into the generated migration file;
  snapshots are not required at run time and never loaded by `Ecto.Migrator`.
  """

  alias AshExclusiveArc.ArcReference
  alias AshExclusiveArc.Resource.Info
  alias Spark.Dsl.Extension

  @snapshot_version 1

  @type ref :: %{
          name: atom(),
          destination: String.t(),
          attribute_name: atom(),
          attribute_type: atom()
        }

  @type arc :: %{
          name: atom(),
          referential_integrity: boolean(),
          archive_aware: boolean(),
          archive_column: String.t() | nil,
          references: [ref()]
        }

  @type t :: %{
          resource: String.t(),
          table: String.t(),
          snapshot_version: pos_integer(),
          arcs: [arc()]
        }

  @doc """
  Builds a snapshot of every exclusive arc currently defined on `resource`.

  Arcs and references are sorted by name so subsequent snapshots produce stable
  diffs regardless of DSL declaration order.
  """
  @spec build(Ash.Resource.t()) :: t()
  def build(resource) do
    arcs =
      resource
      |> Info.arcs()
      |> Enum.map(&build_arc(resource, &1))
      |> Enum.sort_by(& &1.name)

    %{
      resource: module_to_string(resource),
      table: detect_table(resource),
      snapshot_version: @snapshot_version,
      arcs: arcs
    }
  end

  @doc "JSON-encodes a snapshot. Output is pretty-printed for diff-friendliness."
  @spec encode(t()) :: String.t()
  def encode(snapshot) do
    snapshot
    |> to_encodable()
    |> Jason.encode!(pretty: true)
  end

  @doc "Parses a JSON-encoded snapshot back into the canonical map form."
  @spec decode(String.t()) :: {:ok, t()} | {:error, term()}
  def decode(json) do
    with {:ok, raw} <- Jason.decode(json) do
      {:ok, from_encodable(raw)}
    end
  end

  @doc "Reads a snapshot from disk. Returns `{:error, :enoent}` when missing."
  @spec read(Path.t()) :: {:ok, t()} | {:error, :enoent | term()}
  def read(path) do
    case File.read(path) do
      {:ok, body} -> decode(body)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Writes `snapshot` to `path`, creating intermediate directories as needed."
  @spec write(Path.t(), t()) :: :ok | {:error, term()}
  def write(path, snapshot) do
    with :ok <- File.mkdir_p(Path.dirname(path)) do
      File.write(path, encode(snapshot))
    end
  end

  @doc """
  Compares two snapshots. Returns `:no_changes` when equal, otherwise a map with
  `:added`, `:removed`, and `:changed` arc lists.
  """
  @spec diff(t() | nil, t()) ::
          :no_changes | %{added: [arc()], removed: [arc()], changed: [arc()]}
  def diff(nil, %{arcs: arcs}), do: %{added: arcs, removed: [], changed: []}

  def diff(%{arcs: old_arcs}, %{arcs: new_arcs}) when old_arcs == new_arcs, do: :no_changes

  def diff(%{arcs: old_arcs}, %{arcs: new_arcs}) do
    old_by_name = Map.new(old_arcs, &{&1.name, &1})
    new_by_name = Map.new(new_arcs, &{&1.name, &1})

    added = for arc <- new_arcs, not Map.has_key?(old_by_name, arc.name), do: arc
    removed = for arc <- old_arcs, not Map.has_key?(new_by_name, arc.name), do: arc

    changed =
      for arc <- new_arcs,
          old = old_by_name[arc.name],
          old != nil,
          old != arc,
          do: arc

    %{added: added, removed: removed, changed: changed}
  end

  @doc """
  Returns UP SQL statements for the snapshot. Pass an arc name to limit output
  to a single arc; pass `nil` (the default) to emit statements for every arc with
  `referential_integrity: true`.
  """
  @spec up_statements(t(), atom() | nil) :: [String.t()]
  def up_statements(snapshot, arc_name \\ nil) do
    snapshot
    |> arcs_for(arc_name)
    |> Enum.flat_map(&arc_up_statements(&1, snapshot.table))
  end

  @doc "DOWN counterpart of `up_statements/2`."
  @spec down_statements(t(), atom() | nil) :: [String.t()]
  def down_statements(snapshot, arc_name \\ nil) do
    snapshot
    |> arcs_for(arc_name)
    |> Enum.flat_map(&arc_down_statements(&1, snapshot.table))
  end

  @doc """
  Default on-disk location for a snapshot, given a repo module and table name.

  Mirrors `ash_postgres`' convention: `priv/<repo>/exclusive_arc_snapshots/<table>.json`.
  """
  @spec default_path(module(), String.t()) :: Path.t()
  def default_path(repo, table) do
    repo_segment =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    Path.join(["priv", repo_segment, "exclusive_arc_snapshots", "#{table}.json"])
  end

  # ---------- internals ----------

  defp build_arc(resource, arc) do
    ri? = Info.referential_integrity?(resource, arc.name)

    refs =
      arc.references
      |> Enum.map(&build_ref/1)
      |> Enum.sort_by(& &1.name)

    %{
      name: arc.name,
      referential_integrity: ri?,
      archive_aware: arc.archive_aware,
      archive_column: archive_column(resource, arc),
      references: refs
    }
  end

  defp build_ref(%ArcReference{} = ref) do
    %{
      name: ref.name,
      destination: module_to_string(ref.destination),
      attribute_name: ArcReference.attribute_name(ref),
      attribute_type: ref.attribute_type
    }
  end

  defp archive_column(resource, arc) do
    case Extension.get_persisted(resource, {:exclusive_arc_check, arc.name}) do
      %{archive_column: col} -> col
      _ -> nil
    end
  end

  defp detect_table(resource) do
    case Extension.get_persisted(resource, {:exclusive_arc_check, first_arc_name(resource)}) do
      %{table: table} -> table
      _ -> Macro.underscore(List.last(Module.split(resource))) <> "s"
    end
  end

  defp first_arc_name(resource) do
    case Info.arcs(resource) do
      [arc | _] -> arc.name
      [] -> nil
    end
  end

  defp arcs_for(snapshot, nil) do
    Enum.filter(snapshot.arcs, & &1.referential_integrity)
  end

  defp arcs_for(snapshot, arc_name) do
    Enum.filter(snapshot.arcs, &(&1.name == arc_name and &1.referential_integrity))
  end

  defp arc_up_statements(arc, table) do
    [
      build_check_sql(:up, table, arc)
      | Enum.map(arc.references, &build_index_sql(:up, table, arc, &1))
    ]
  end

  defp arc_down_statements(arc, table) do
    Enum.map(arc.references, &build_index_sql(:down, table, arc, &1)) ++
      [build_check_sql(:down, table, arc)]
  end

  defp build_check_sql(:up, table, arc) do
    attr_names = Enum.map(arc.references, & &1.attribute_name)

    expr =
      attr_names
      |> Enum.map(&"(CASE WHEN #{&1} IS NOT NULL THEN 1 ELSE 0 END)")
      |> Enum.join(" +\n     ")

    String.trim("""
    ALTER TABLE #{table} ADD CONSTRAINT #{check_name(table, arc.name)}
    CHECK (
      #{expr} = 1
    )
    """)
  end

  defp build_check_sql(:down, table, arc) do
    "ALTER TABLE #{table} DROP CONSTRAINT IF EXISTS #{check_name(table, arc.name)}"
  end

  defp build_index_sql(:up, table, arc, ref) do
    "CREATE INDEX #{index_name(table, ref.attribute_name)} ON #{table} (#{ref.attribute_name}) WHERE #{index_where(arc, ref)}"
  end

  defp build_index_sql(:down, table, _arc, ref) do
    "DROP INDEX IF EXISTS #{index_name(table, ref.attribute_name)}"
  end

  defp check_name(table, arc_name), do: "#{table}_#{arc_name}_exclusive_arc"
  defp index_name(table, attr_name), do: "#{table}_#{attr_name}_exclusive_index"

  defp index_where(arc, ref) do
    if arc.archive_column && arc.archive_aware do
      "#{ref.attribute_name} IS NOT NULL AND #{arc.archive_column} IS NULL"
    else
      "#{ref.attribute_name} IS NOT NULL"
    end
  end

  defp module_to_string(nil), do: nil
  defp module_to_string(mod) when is_atom(mod), do: Atom.to_string(mod)

  defp to_encodable(snapshot) do
    %{
      "resource" => snapshot.resource,
      "table" => snapshot.table,
      "snapshot_version" => snapshot.snapshot_version,
      "arcs" => Enum.map(snapshot.arcs, &arc_to_encodable/1)
    }
  end

  defp arc_to_encodable(arc) do
    %{
      "name" => Atom.to_string(arc.name),
      "referential_integrity" => arc.referential_integrity,
      "archive_aware" => arc.archive_aware,
      "archive_column" => arc.archive_column,
      "references" => Enum.map(arc.references, &ref_to_encodable/1)
    }
  end

  defp ref_to_encodable(ref) do
    %{
      "name" => Atom.to_string(ref.name),
      "destination" => ref.destination,
      "attribute_name" => Atom.to_string(ref.attribute_name),
      "attribute_type" => Atom.to_string(ref.attribute_type)
    }
  end

  defp from_encodable(%{"resource" => resource, "table" => table, "arcs" => arcs} = raw) do
    %{
      resource: resource,
      table: table,
      snapshot_version: Map.get(raw, "snapshot_version", @snapshot_version),
      arcs: Enum.map(arcs, &arc_from_encodable/1)
    }
  end

  defp arc_from_encodable(raw) do
    %{
      name: String.to_atom(raw["name"]),
      referential_integrity: raw["referential_integrity"],
      archive_aware: raw["archive_aware"],
      archive_column: raw["archive_column"],
      references: Enum.map(raw["references"], &ref_from_encodable/1)
    }
  end

  defp ref_from_encodable(raw) do
    %{
      name: String.to_atom(raw["name"]),
      destination: raw["destination"],
      attribute_name: String.to_atom(raw["attribute_name"]),
      attribute_type: String.to_atom(raw["attribute_type"])
    }
  end
end
