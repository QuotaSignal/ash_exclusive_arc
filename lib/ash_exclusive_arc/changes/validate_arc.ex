defmodule AshExclusiveArc.Changes.ValidateArc do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      set_count =
        Enum.count(opts[:attributes], fn attr ->
          Ash.Changeset.get_attribute(changeset, attr) != nil
        end)

      if set_count == 1 do
        changeset
      else
        names = Enum.map_join(opts[:references], ", ", &inspect/1)

        message =
          case set_count do
            0 -> "exactly one of #{names} must be set, but none were"
            n -> "exactly one of #{names} must be set, but #{n} were"
          end

        Ash.Changeset.add_error(changeset, Ash.Error.Changes.InvalidAttribute.exception(
          field: opts[:arc_name],
          message: message
        ))
      end
    end)
  end

  @impl true
  def atomic(_changeset, opts, _context) do
    {:not_atomic, "AshExclusiveArc validation for #{inspect(opts[:arc_name])} cannot run atomically"}
  end
end
