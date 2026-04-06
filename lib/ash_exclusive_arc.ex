defmodule AshExclusiveArc do
  @moduledoc """
  Exclusive belongs-to (exclusive arc) pattern for Ash resources.

  See `AshExclusiveArc.Resource` for DSL documentation and usage examples.
  See `AshExclusiveArc.Migration` for generating CHECK constraints and partial indexes.
  """

  alias AshExclusiveArc.ArcReference
  alias AshExclusiveArc.Resource.Info

  @type record :: Ash.Resource.record()

  @doc """
  Returns the type atom of the currently set reference for the given arc.

  ## Examples

      iex> AshExclusiveArc.type(cart_item, :purchasable)
      :product_variant

      iex> AshExclusiveArc.type(cart_item, :owner)
      :customer
  """
  @spec type(record(), atom()) :: atom() | nil
  def type(record, arc_name) do
    arc = Info.arc!(record.__struct__, arc_name)

    Enum.find_value(arc.references, fn ref ->
      if Map.get(record, ArcReference.attribute_name(ref)) != nil, do: ref.name
    end)
  end

  @doc """
  Returns the loaded associated record for the given arc, along with its type.

  Returns `{:ok, {type_atom, record}}` if loaded, `{:ok, nil}` if the FK is set
  but the relationship is not loaded, or `{:error, :not_set}` if no FK is set.

  ## Examples

      iex> AshExclusiveArc.get(cart_item, :purchasable)
      {:ok, {:product_variant, %MyApp.ProductVariant{...}}}
  """
  @spec get(record(), atom()) :: {:ok, {atom(), record()}} | {:ok, nil} | {:error, :not_set}
  def get(record, arc_name) do
    case type(record, arc_name) do
      nil ->
        {:error, :not_set}

      ref_name ->
        case Map.get(record, ref_name) do
          %Ash.NotLoaded{} -> {:ok, nil}
          nil -> {:ok, nil}
          loaded -> {:ok, {ref_name, loaded}}
        end
    end
  end

  @doc """
  Sets the foreign key for the given reference type on a changeset, and nils all
  other FKs in the same arc.

  Accepts a record (extracts `id`) or a raw ID value.

  ## Examples

      changeset
      |> AshExclusiveArc.set(:purchasable, :product_variant, variant_id)

      changeset
      |> AshExclusiveArc.set(:owner, :customer, customer)
  """
  @spec set(Ash.Changeset.t(), atom(), atom(), term()) :: Ash.Changeset.t()
  def set(changeset, arc_name, ref_name, value) do
    resource = changeset.resource
    arc = Info.arc!(resource, arc_name)

    unless Enum.any?(arc.references, &(&1.name == ref_name)) do
      raise ArgumentError,
            "No reference named #{inspect(ref_name)} in arc #{inspect(arc_name)} on #{inspect(resource)}"
    end

    id_value =
      case value do
        %{id: id} -> id
        id -> id
      end

    Enum.reduce(arc.references, changeset, fn ref, cs ->
      attr = ArcReference.attribute_name(ref)
      val = if ref.name == ref_name, do: id_value

      Ash.Changeset.force_change_attribute(cs, attr, val)
    end)
  end
end
