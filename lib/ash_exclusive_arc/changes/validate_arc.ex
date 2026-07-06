defmodule AshExclusiveArc.Changes.ValidateArc do
  @moduledoc false
  use Ash.Resource.Change

  import Ash.Expr

  alias Ash.Changeset
  alias Ash.Error.Changes.InvalidAttribute

  @impl true
  def change(changeset, opts, _context) do
    Changeset.before_action(changeset, fn changeset ->
      set_count =
        Enum.count(opts[:attributes], fn attr ->
          Changeset.get_attribute(changeset, attr) != nil
        end)

      if set_count == 1 do
        changeset
      else
        names = reference_names(opts)

        message =
          case set_count do
            0 -> "exactly one of #{names} must be set, but none were"
            n -> "exactly one of #{names} must be set, but #{n} were"
          end

        Changeset.add_error(
          changeset,
          InvalidAttribute.exception(field: opts[:arc_name], message: message)
        )
      end
    end)
  end

  @impl true
  def atomic(_changeset, opts, _context) do
    # "Exactly one FK non-null" is the same predicate as the arc's DB CHECK
    # constraint, so it can be enforced atomically. Emit it as an atomic
    # validation (condition-true => error) over the arc's atomic refs, mirroring
    # `Ash.Resource.Validation.AttributesPresent`. This keeps `require_atomic?`
    # actions and `:atomic` / `:atomic_batches` bulk strategies working; the
    # `change/3` before_action above still covers non-atomic execution.
    attributes = opts[:attributes]
    values = Enum.map(attributes, fn attr -> expr(^atomic_ref(attr)) end)
    nil_count = expr(count_nils(^values))
    exactly_nil = length(attributes) - 1
    names = reference_names(opts)

    {:atomic, %{},
     [
       {:atomic, attributes, expr(^nil_count != ^exactly_nil),
        expr(
          error(^InvalidAttribute, %{
            field: ^opts[:arc_name],
            message: ^"exactly one of #{names} must be set"
          })
        )}
     ]}
  end

  defp reference_names(opts), do: Enum.map_join(opts[:references], ", ", &inspect/1)
end
