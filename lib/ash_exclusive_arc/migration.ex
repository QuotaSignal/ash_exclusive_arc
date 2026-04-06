defmodule AshExclusiveArc.Migration do
  @moduledoc """
  Migration helpers for generating CHECK constraints and partial unique indexes
  for exclusive arc relationships.

  ## Usage

  After running `mix ash_postgres.generate_migrations`, add the constraints
  in a separate migration:

      defmodule MyApp.Repo.Migrations.AddExclusiveArcConstraints do
        use Ecto.Migration

        def up do
          AshExclusiveArc.Migration.up(MyApp.CartItem)
        end

        def down do
          AshExclusiveArc.Migration.down(MyApp.CartItem)
        end
      end

  Or for a specific arc only:

      def up do
        AshExclusiveArc.Migration.up(MyApp.CartItem, :purchasable)
      end
  """

  alias AshExclusiveArc.Resource.Info

  @doc "Returns UP SQL statements for all exclusive arcs (or a specific arc) on the resource."
  def up_statements(resource, arc_name \\ nil)

  def up_statements(resource, nil) do
    resource
    |> ri_arcs()
    |> Enum.flat_map(&arc_statements(resource, &1, :up))
  end

  def up_statements(resource, arc_name) do
    arc = Info.arc!(resource, arc_name)

    if Info.referential_integrity?(resource, arc_name),
      do: arc_statements(resource, arc, :up),
      else: []
  end

  @doc "Returns DOWN SQL statements for all exclusive arcs (or a specific arc) on the resource."
  def down_statements(resource, arc_name \\ nil)

  def down_statements(resource, nil) do
    resource
    |> ri_arcs()
    |> Enum.flat_map(&arc_statements(resource, &1, :down))
  end

  def down_statements(resource, arc_name) do
    arc = Info.arc!(resource, arc_name)

    if Info.referential_integrity?(resource, arc_name),
      do: arc_statements(resource, arc, :down),
      else: []
  end

  @doc "Executes UP migration for all exclusive arcs (or a specific arc) on the resource."
  def up(resource, arc_name \\ nil), do: execute_statements(up_statements(resource, arc_name))

  @doc "Executes DOWN migration for all exclusive arcs (or a specific arc) on the resource."
  def down(resource, arc_name \\ nil), do: execute_statements(down_statements(resource, arc_name))

  defp execute_statements(statements) do
    Enum.each(statements, &Ecto.Migration.execute/1)
  end

  defp ri_arcs(resource) do
    resource
    |> Info.arcs()
    |> Enum.filter(&Info.referential_integrity?(resource, &1.name))
  end

  defp arc_statements(resource, arc, :up) do
    check = check_info(resource, arc)
    indexes = index_infos(resource, arc)

    [check.up | Enum.map(indexes, &"CREATE INDEX #{&1.index_name} ON #{&1.table} (#{&1.column}) WHERE #{&1.where}")]
  end

  defp arc_statements(resource, arc, :down) do
    check = check_info(resource, arc)
    indexes = index_infos(resource, arc)

    Enum.map(indexes, &"DROP INDEX IF EXISTS #{&1.index_name}") ++ [check.down]
  end

  defp check_info(resource, arc) do
    case Spark.Dsl.Extension.get_persisted(resource, {:exclusive_arc_check, arc.name}) do
      nil -> build_check_info(arc)
      info -> info
    end
  end

  defp index_infos(resource, arc) do
    Enum.map(arc.references, fn ref ->
      case Spark.Dsl.Extension.get_persisted(resource, {:exclusive_arc_index, arc.name, ref.name}) do
        nil -> build_index_info(ref)
        info -> info
      end
    end)
  end

  defp build_check_info(arc) do
    raise """
    Could not find persisted constraint info for arc #{inspect(arc.name)}.
    Ensure the resource uses the AshExclusiveArc.Resource extension and has referential_integrity enabled.
    """
  end

  defp build_index_info(ref) do
    raise """
    Could not find persisted index info for reference #{inspect(ref.name)}.
    Ensure the resource uses the AshExclusiveArc.Resource extension and has referential_integrity enabled.
    """
  end
end
