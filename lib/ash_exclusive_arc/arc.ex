defmodule AshExclusiveArc.Arc do
  @moduledoc false
  @type t :: %__MODULE__{
          name: atom(),
          referential_integrity: boolean() | nil,
          archive_column: atom() | nil,
          archive_aware: boolean(),
          references: [AshExclusiveArc.ArcReference.t()]
        }

  defstruct [
    :name,
    :referential_integrity,
    :archive_column,
    :__spark_metadata__,
    archive_aware: true,
    references: []
  ]
end
