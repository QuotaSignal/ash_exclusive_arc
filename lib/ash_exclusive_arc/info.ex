defmodule AshExclusiveArc.Resource.Info do
  @moduledoc "Introspection helpers for `AshExclusiveArc.Resource`"
  use Spark.InfoGenerator, extension: AshExclusiveArc.Resource, sections: [:exclusive_arc]

  @doc "Returns all arc definitions for the given resource."
  def arcs(resource) do
    Spark.Dsl.Extension.get_entities(resource, [:exclusive_arc])
  end

  @doc "Returns the arc definition with the given name, or nil."
  def arc(resource, name) do
    resource
    |> arcs()
    |> Enum.find(&(&1.name == name))
  end

  @doc "Returns the arc definition with the given name, or raises."
  def arc!(resource, name) do
    case arc(resource, name) do
      nil -> raise "No exclusive arc named #{inspect(name)} found on #{inspect(resource)}"
      arc -> arc
    end
  end

  @doc """
  Returns whether the given arc should use database-level referential integrity.

  Checks the arc-level setting first, then falls back to the section-level default.
  """
  def referential_integrity?(resource, arc_name) do
    arc = arc!(resource, arc_name)

    case arc.referential_integrity do
      nil -> exclusive_arc_referential_integrity!(resource)
      value -> value
    end
  end
end
