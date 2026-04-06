defmodule AshExclusiveArcTest do
  use ExUnit.Case

  alias AshExclusiveArc.Test.CartItem
  alias AshExclusiveArc.Resource.Info

  describe "DSL introspection" do
    test "arcs are defined on the resource" do
      arcs = Info.arcs(CartItem)
      assert length(arcs) == 2
      assert Enum.map(arcs, & &1.name) |> Enum.sort() == [:owner, :purchasable]
    end

    test "arc references are populated" do
      arc = Info.arc!(CartItem, :purchasable)
      assert length(arc.references) == 2
      assert Enum.map(arc.references, & &1.name) |> Enum.sort() == [:product, :subscription_plan]
    end

    test "arc reference destinations are correct" do
      arc = Info.arc!(CartItem, :purchasable)
      product_ref = Enum.find(arc.references, &(&1.name == :product))
      assert product_ref.destination == AshExclusiveArc.Test.Product
    end

    test "referential_integrity defaults to true" do
      assert Info.referential_integrity?(CartItem, :purchasable) == true
      assert Info.referential_integrity?(CartItem, :owner) == true
    end
  end

  describe "transformer" do
    test "adds nullable FK attributes for each reference" do
      attrs = Ash.Resource.Info.attributes(CartItem)
      attr_names = Enum.map(attrs, & &1.name)

      assert :product_id in attr_names
      assert :subscription_plan_id in attr_names
      assert :customer_id in attr_names
      assert :guest_session_id in attr_names
    end

    test "FK attributes are nullable" do
      product_attr = Ash.Resource.Info.attribute(CartItem, :product_id)
      assert product_attr.allow_nil? == true
    end

    test "adds belongs_to relationships for each reference" do
      rels = Ash.Resource.Info.relationships(CartItem)
      rel_names = Enum.map(rels, & &1.name)

      assert :product in rel_names
      assert :subscription_plan in rel_names
      assert :customer in rel_names
      assert :guest_session in rel_names
    end

    test "belongs_to relationships have correct destinations" do
      product_rel = Ash.Resource.Info.relationship(CartItem, :product)
      assert product_rel.destination == AshExclusiveArc.Test.Product

      customer_rel = Ash.Resource.Info.relationship(CartItem, :customer)
      assert customer_rel.destination == AshExclusiveArc.Test.Customer
    end
  end

  describe "public API" do
    test "type/2 returns the set reference type" do
      item = %CartItem{
        id: Ash.UUID.generate(),
        product_id: Ash.UUID.generate(),
        subscription_plan_id: nil,
        customer_id: Ash.UUID.generate(),
        guest_session_id: nil,
        quantity: 1
      }

      assert AshExclusiveArc.type(item, :purchasable) == :product
      assert AshExclusiveArc.type(item, :owner) == :customer
    end

    test "type/2 returns nil when nothing is set" do
      item = %CartItem{
        id: Ash.UUID.generate(),
        product_id: nil,
        subscription_plan_id: nil,
        customer_id: nil,
        guest_session_id: nil,
        quantity: 1
      }

      assert AshExclusiveArc.type(item, :purchasable) == nil
    end
  end

  describe "migration" do
    test "up_statements generates CHECK constraint SQL" do
      statements = AshExclusiveArc.Migration.up_statements(CartItem)

      check_statements = Enum.filter(statements, &String.contains?(&1, "CHECK"))
      assert length(check_statements) == 2

      purchasable_check = Enum.find(check_statements, &String.contains?(&1, "purchasable"))
      assert String.contains?(purchasable_check, "product_id")
      assert String.contains?(purchasable_check, "subscription_plan_id")
      assert String.contains?(purchasable_check, "= 1")
    end

    test "up_statements generates partial index SQL" do
      statements = AshExclusiveArc.Migration.up_statements(CartItem)

      index_statements = Enum.filter(statements, &String.contains?(&1, "CREATE INDEX"))
      assert length(index_statements) == 4
    end

    test "down_statements generates DROP statements" do
      statements = AshExclusiveArc.Migration.down_statements(CartItem)

      assert Enum.any?(statements, &String.contains?(&1, "DROP CONSTRAINT"))
      assert Enum.any?(statements, &String.contains?(&1, "DROP INDEX"))
    end
  end
end
