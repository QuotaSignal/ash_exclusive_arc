defmodule AshExclusiveArc.Transformers.SetupArcs do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Ash.Resource.Builder
  alias Ash.Resource.Info, as: ResourceInfo
  alias AshExclusiveArc.ArcReference
  alias Spark.Dsl.Extension
  alias Spark.Dsl.Transformer

  @before_transformers [
    Ash.Resource.Transformers.DefaultAccept,
    Ash.Resource.Transformers.SetTypes
  ]

  def before?(transformer) when transformer in @before_transformers, do: true
  def before?(_), do: false

  def transform(dsl_state) do
    arcs = Extension.get_entities(dsl_state, [:exclusive_arc])

    if Enum.empty?(arcs) do
      {:ok, dsl_state}
    else
      dsl_state = ensure_default_accept(dsl_state)

      Enum.reduce_while(arcs, {:ok, dsl_state}, fn arc, {:ok, dsl_state} ->
        case setup_arc(dsl_state, arc) do
          {:ok, dsl_state} -> {:cont, {:ok, dsl_state}}
          {:error, _} = error -> {:halt, error}
        end
      end)
    end
  end

  defp setup_arc(dsl_state, arc) do
    with {:ok, dsl_state} <- add_attributes(dsl_state, arc),
         {:ok, dsl_state} <- add_relationships(dsl_state, arc),
         {:ok, dsl_state} <- add_validation(dsl_state, arc) do
      persist_constraint_info(dsl_state, arc)
    end
  end

  defp add_attributes(dsl_state, arc) do
    reduce_refs(arc, dsl_state, fn ref, dsl_state ->
      if ref.define_attribute do
        Builder.add_new_attribute(
          dsl_state,
          ArcReference.attribute_name(ref),
          ref.attribute_type,
          allow_nil?: true,
          writable?: true,
          public?: true
        )
      else
        {:ok, dsl_state}
      end
    end)
  end

  defp add_relationships(dsl_state, arc) do
    reduce_refs(arc, dsl_state, fn ref, dsl_state ->
      Builder.add_new_relationship(
        dsl_state,
        :belongs_to,
        ref.name,
        ref.destination,
        allow_nil?: true,
        attribute_writable?: true,
        public?: true,
        define_attribute?: false
      )
    end)
  end

  defp add_validation(dsl_state, arc) do
    attr_names = Enum.map(arc.references, &ArcReference.attribute_name/1)
    ref_names = Enum.map(arc.references, & &1.name)

    Builder.add_change(
      dsl_state,
      {AshExclusiveArc.Changes.ValidateArc,
       [arc_name: arc.name, attributes: attr_names, references: ref_names]}
    )
  end

  defp persist_constraint_info(dsl_state, arc) do
    section_ri =
      Transformer.get_option(dsl_state, [:exclusive_arc], :referential_integrity)

    arc_ri = if is_nil(arc.referential_integrity), do: section_ri, else: arc.referential_integrity

    if arc_ri do
      do_persist_constraint_info(dsl_state, arc)
    else
      {:ok, dsl_state}
    end
  end

  defp do_persist_constraint_info(dsl_state, arc) do
    table = detect_table(dsl_state)
    archive_column = detect_archive_column(dsl_state, arc)
    attr_names = Enum.map(arc.references, &ArcReference.attribute_name/1)

    check_name = "#{table}_#{arc.name}_exclusive_arc"

    check_expr =
      attr_names
      |> Enum.map(&"(CASE WHEN #{&1} IS NOT NULL THEN 1 ELSE 0 END)")
      |> Enum.join(" +\n     ")

    up_sql =
      String.trim("""
      ALTER TABLE #{table} ADD CONSTRAINT #{check_name}
      CHECK (
        #{check_expr} = 1
      )
      """)

    dsl_state =
      Transformer.persist(dsl_state, {:exclusive_arc_check, arc.name}, %{
        table: table,
        constraint_name: check_name,
        up: up_sql,
        down: "ALTER TABLE #{table} DROP CONSTRAINT IF EXISTS #{check_name}",
        attribute_names: attr_names,
        archive_column: archive_column
      })

    dsl_state =
      Enum.reduce(arc.references, dsl_state, fn ref, dsl_state ->
        attr_name = ArcReference.attribute_name(ref)
        index_name = "#{table}_#{attr_name}_exclusive_index"

        where_clause =
          if archive_column && arc.archive_aware do
            "#{attr_name} IS NOT NULL AND #{archive_column} IS NULL"
          else
            "#{attr_name} IS NOT NULL"
          end

        Transformer.persist(
          dsl_state,
          {:exclusive_arc_index, arc.name, ref.name},
          %{table: table, index_name: index_name, column: attr_name, where: where_clause}
        )
      end)

    {:ok, dsl_state}
  end

  defp detect_table(dsl_state) do
    case Transformer.get_option(dsl_state, [:postgres], :table) do
      nil ->
        dsl_state
        |> Transformer.get_persisted(:module)
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
        |> Kernel.<>("s")

      table ->
        table
    end
  end

  defp detect_archive_column(dsl_state, arc) do
    cond do
      arc.archive_column ->
        Atom.to_string(arc.archive_column)

      !arc.archive_aware ->
        nil

      true ->
        case ResourceInfo.attribute(dsl_state, :archived_at) do
          nil -> nil
          _attr -> "archived_at"
        end
    end
  end

  defp reduce_refs(arc, dsl_state, fun) do
    Enum.reduce_while(arc.references, {:ok, dsl_state}, fn ref, {:ok, dsl_state} ->
      case fun.(ref, dsl_state) do
        {:ok, dsl_state} -> {:cont, {:ok, dsl_state}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp ensure_default_accept(dsl_state) do
    case Transformer.get_option(dsl_state, [:actions], :default_accept) do
      nil -> Transformer.set_option(dsl_state, [:actions], :default_accept, :*)
      _ -> dsl_state
    end
  end
end
