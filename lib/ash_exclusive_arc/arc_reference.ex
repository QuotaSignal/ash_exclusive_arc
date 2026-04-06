defmodule AshExclusiveArc.ArcReference do
  @moduledoc false
  defstruct [
    :name,
    :destination,
    :attribute_type,
    :__spark_metadata__,
    define_attribute: true
  ]

  def attribute_name(%__MODULE__{name: name}), do: :"#{name}_id"
end
