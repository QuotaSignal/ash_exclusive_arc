defmodule AshExclusiveArcIntegrationTest do
  use AshExclusiveArc.RepoCase

  alias AshExclusiveArc.Test.{CartItem, Product, SubscriptionPlan, Customer, GuestSession}

  defp create_product!(name \\ "Widget") do
    Product
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.create!()
  end

  defp create_plan!(name \\ "Monthly") do
    SubscriptionPlan
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.create!()
  end

  defp create_customer!(email \\ "test@example.com") do
    Customer
    |> Ash.Changeset.for_create(:create, %{email: email})
    |> Ash.create!()
  end

  defp create_guest!(token \\ "sess_abc123") do
    GuestSession
    |> Ash.Changeset.for_create(:create, %{session_token: token})
    |> Ash.create!()
  end

  describe "creating records with one FK set" do
    test "succeeds with product + customer" do
      product = create_product!()
      customer = create_customer!()

      item =
        CartItem
        |> Ash.Changeset.for_create(:create, %{
          product_id: product.id,
          customer_id: customer.id,
          quantity: 3
        })
        |> Ash.create!()

      assert item.product_id == product.id
      assert item.subscription_plan_id == nil
      assert item.customer_id == customer.id
      assert item.guest_session_id == nil
      assert item.quantity == 3
    end

    test "succeeds with subscription_plan + guest_session" do
      plan = create_plan!()
      guest = create_guest!()

      item =
        CartItem
        |> Ash.Changeset.for_create(:create, %{
          subscription_plan_id: plan.id,
          guest_session_id: guest.id
        })
        |> Ash.create!()

      assert item.subscription_plan_id == plan.id
      assert item.product_id == nil
      assert item.guest_session_id == guest.id
      assert item.customer_id == nil
    end
  end

  describe "validation rejects invalid states" do
    test "fails with zero FKs set for an arc" do
      customer = create_customer!()

      assert_raise Ash.Error.Invalid, ~r/exactly one of/, fn ->
        CartItem
        |> Ash.Changeset.for_create(:create, %{
          customer_id: customer.id
        })
        |> Ash.create!()
      end
    end

    test "fails with two FKs set for an arc" do
      product = create_product!()
      plan = create_plan!()
      customer = create_customer!()

      assert_raise Ash.Error.Invalid, ~r/exactly one of/, fn ->
        CartItem
        |> Ash.Changeset.for_create(:create, %{
          product_id: product.id,
          subscription_plan_id: plan.id,
          customer_id: customer.id
        })
        |> Ash.create!()
      end
    end

    test "fails with zero FKs for both arcs" do
      assert_raise Ash.Error.Invalid, fn ->
        CartItem
        |> Ash.Changeset.for_create(:create, %{quantity: 1})
        |> Ash.create!()
      end
    end
  end

  describe "updating records" do
    test "can switch from one reference to another in an arc" do
      product = create_product!("Widget A")
      plan = create_plan!()
      customer = create_customer!()

      item =
        CartItem
        |> Ash.Changeset.for_create(:create, %{
          product_id: product.id,
          customer_id: customer.id
        })
        |> Ash.create!()

      updated =
        item
        |> Ash.Changeset.for_update(:update, %{
          product_id: nil,
          subscription_plan_id: plan.id
        })
        |> Ash.update!()

      assert updated.product_id == nil
      assert updated.subscription_plan_id == plan.id
    end
  end

  describe "set/4 helper" do
    test "sets the correct FK and nils others" do
      product = create_product!()
      plan = create_plan!()
      customer = create_customer!()

      item =
        CartItem
        |> Ash.Changeset.for_create(:create, %{
          product_id: product.id,
          customer_id: customer.id
        })
        |> Ash.create!()

      updated =
        item
        |> Ash.Changeset.for_update(:update, %{})
        |> AshExclusiveArc.set(:purchasable, :subscription_plan, plan.id)
        |> Ash.update!()

      assert updated.product_id == nil
      assert updated.subscription_plan_id == plan.id
    end

    test "accepts a record with an id field" do
      product = create_product!()
      customer = create_customer!()

      item =
        CartItem
        |> Ash.Changeset.for_create(:create, %{customer_id: customer.id})
        |> AshExclusiveArc.set(:purchasable, :product, product)
        |> Ash.create!()

      assert item.product_id == product.id
    end
  end

  describe "type/2 and get/2" do
    test "type returns the correct reference name" do
      product = create_product!()
      customer = create_customer!()

      item =
        CartItem
        |> Ash.Changeset.for_create(:create, %{
          product_id: product.id,
          customer_id: customer.id
        })
        |> Ash.create!()

      assert AshExclusiveArc.type(item, :purchasable) == :product
      assert AshExclusiveArc.type(item, :owner) == :customer
    end

    test "get returns the loaded record" do
      product = create_product!("Loaded Widget")
      customer = create_customer!()

      item =
        CartItem
        |> Ash.Changeset.for_create(:create, %{
          product_id: product.id,
          customer_id: customer.id
        })
        |> Ash.create!()

      item = Ash.load!(item, [:product, :customer])

      assert {:ok, {:product, loaded_product}} = AshExclusiveArc.get(item, :purchasable)
      assert loaded_product.name == "Loaded Widget"

      assert {:ok, {:customer, _}} = AshExclusiveArc.get(item, :owner)
    end
  end
end
