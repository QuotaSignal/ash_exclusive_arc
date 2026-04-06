defmodule AshExclusiveArc.ArcReference do
  @moduledoc false
  @type t :: %__MODULE__{
          name: atom(),
          destination: module(),
          attribute_type: atom(),
          define_attribute: boolean()
        }

  defstruct [
    :name,
    :destination,
    :attribute_type,
    :__spark_metadata__,
    define_attribute: true
  ]

  @spec attribute_name(t()) :: atom()
  def attribute_name(%__MODULE__{name: name}), do: :"#{name}_id"
end
