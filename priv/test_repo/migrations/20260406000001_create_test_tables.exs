defmodule AshExclusiveArc.TestRepo.Migrations.CreateTestTables do
  use Ecto.Migration

  def up do
    create table(:products, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :name, :text, null: false
    end

    create table(:subscription_plans, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :name, :text, null: false
    end

    create table(:customers, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :email, :text, null: false
    end

    create table(:guest_sessions, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :session_token, :text, null: false
    end

    create table(:cart_items, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :quantity, :integer, null: false, default: 1
      add :product_id, references(:products, type: :uuid, on_delete: :nothing)
      add :subscription_plan_id, references(:subscription_plans, type: :uuid, on_delete: :nothing)
      add :customer_id, references(:customers, type: :uuid, on_delete: :nothing)
      add :guest_session_id, references(:guest_sessions, type: :uuid, on_delete: :nothing)
    end

    AshExclusiveArc.Migration.up(AshExclusiveArc.Test.CartItem)
  end

  def down do
    AshExclusiveArc.Migration.down(AshExclusiveArc.Test.CartItem)
    drop table(:cart_items)
    drop table(:guest_sessions)
    drop table(:customers)
    drop table(:subscription_plans)
    drop table(:products)
  end
end
