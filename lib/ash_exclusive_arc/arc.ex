defmodule AshExclusiveArc.Arc do
  @moduledoc false
  defstruct [
    :name,
    :referential_integrity,
    :archive_column,
    :__spark_metadata__,
    archive_aware: true,
    references: []
  ]
end
