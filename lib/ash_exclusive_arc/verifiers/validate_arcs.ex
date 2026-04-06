defmodule AshExclusiveArc.Verifiers.ValidateArcs do
  @moduledoc false
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    arcs = Spark.Dsl.Extension.get_entities(dsl_state, [:exclusive_arc])

    with :ok <- validate_unique_arc_names(arcs),
         :ok <- validate_references_present(arcs),
         :ok <- validate_unique_reference_names(arcs) do
      validate_no_cross_arc_duplicates(arcs)
    end
  end

  defp validate_unique_arc_names(arcs) do
    case find_duplicates(arcs, & &1.name) do
      [] -> :ok
      dupes -> dsl_error([:exclusive_arc], "Duplicate arc names: #{inspect(dupes)}")
    end
  end

  defp validate_references_present(arcs) do
    case Enum.filter(arcs, &Enum.empty?(&1.references)) do
      [] -> :ok
      empty -> dsl_error([:exclusive_arc], "Arcs must have at least one belongs_to: #{inspect(Enum.map(empty, & &1.name))}")
    end
  end

  defp validate_unique_reference_names(arcs) do
    Enum.reduce_while(arcs, :ok, fn arc, :ok ->
      case find_duplicates(arc.references, & &1.name) do
        [] ->
          {:cont, :ok}

        dupes ->
          {:halt, dsl_error([:exclusive_arc, :arc, arc.name], "Duplicate reference names: #{inspect(dupes)}")}
      end
    end)
  end

  defp validate_no_cross_arc_duplicates(arcs) do
    all_refs = Enum.flat_map(arcs, fn arc ->
      Enum.map(arc.references, &{&1.name, arc.name})
    end)

    case find_duplicates(all_refs, &elem(&1, 0)) do
      [] ->
        :ok

      dup_names ->
        details =
          Enum.map_join(dup_names, ", ", fn name ->
            containing = all_refs |> Enum.filter(&(elem(&1, 0) == name)) |> Enum.map(&elem(&1, 1))
            "#{inspect(name)} appears in arcs #{inspect(containing)}"
          end)

        dsl_error([:exclusive_arc], "Reference names must be unique across all arcs: #{details}")
    end
  end

  defp find_duplicates(items, key_fn) do
    items
    |> Enum.map(key_fn)
    |> then(fn keys -> keys -- Enum.uniq(keys) end)
    |> Enum.uniq()
  end

  defp dsl_error(path, message) do
    {:error, Spark.Error.DslError.exception(path: path, message: message)}
  end
end
