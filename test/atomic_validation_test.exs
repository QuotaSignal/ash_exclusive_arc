defmodule AshExclusiveArc.AtomicValidationTest do
  @moduledoc """
  The exclusive-arc validation must run atomically so that `require_atomic?`
  update actions and `:atomic` / `:atomic_batches` bulk strategies keep working
  on resources that use the extension.
  """
  use AshExclusiveArc.RepoCase

  require Ash.Query

  alias AshExclusiveArc.Test.{CartItem, Customer, Product}

  defp valid_item! do
    product =
      Product |> Ash.Changeset.for_create(:create, %{name: "Widget"}) |> Ash.create!()

    customer =
      Customer
      |> Ash.Changeset.for_create(:create, %{email: "buyer@example.com"})
      |> Ash.create!()

    CartItem
    |> Ash.Changeset.for_create(:create, %{
      product_id: product.id,
      customer_id: customer.id,
      quantity: 1
    })
    |> Ash.create!()
  end

  describe "atomic updates with exclusive arc validation" do
    test "atomic bulk update of an unrelated attribute succeeds" do
      item = valid_item!()

      result =
        CartItem
        |> Ash.Query.filter(id == ^item.id)
        |> Ash.bulk_update(:update, %{quantity: 5},
          strategy: :atomic,
          return_records?: true,
          return_errors?: true
        )

      assert %Ash.BulkResult{status: :success, records: [updated]} = result
      assert updated.quantity == 5
      assert updated.product_id == item.product_id
      assert updated.customer_id == item.customer_id
    end

    test "atomic bulk update that empties an arc is rejected by the arc validation" do
      item = valid_item!()

      result =
        CartItem
        |> Ash.Query.filter(id == ^item.id)
        |> Ash.bulk_update(:update, %{customer_id: nil},
          strategy: :atomic,
          return_errors?: true
        )

      assert %Ash.BulkResult{status: :error, errors: [error | _]} = result
      assert Exception.message(error) =~ "exactly one"
    end
  end
end
