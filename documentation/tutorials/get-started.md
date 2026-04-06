# Get Started with AshExclusiveArc

AshExclusiveArc adds the exclusive belongs-to (exclusive arc) pattern to your Ash resources. This gives you polymorphic relationships backed by real foreign key constraints instead of unsafe `_id` + `_type` string pairs.

## Add the dependency

```elixir
# mix.exs
{:ash_exclusive_arc, "~> 0.1.0"}
```

## Add the extension to your resource

```elixir
defmodule MyApp.CartItem do
  use Ash.Resource,
    domain: MyApp.Shop,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshExclusiveArc.Resource]

  postgres do
    table "cart_items"
    repo MyApp.Repo
  end

  exclusive_arc do
    arc :purchasable do
      belongs_to :product_variant, MyApp.ProductVariant
      belongs_to :subscription_plan, MyApp.SubscriptionPlan
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :quantity, :integer, allow_nil?: false, default: 1, public?: true
  end
end
```

The extension automatically adds:

1. Nullable `product_variant_id` and `subscription_plan_id` attributes
2. `belongs_to :product_variant` and `belongs_to :subscription_plan` relationships
3. A changeset validation ensuring exactly one FK is set on every create/update

## Generate migrations

Run the standard Ash migration generator — the FK columns are picked up automatically:

```bash
mix ash_postgres.generate_migrations
mix ash_postgres.migrate
```

Then add a separate migration for the CHECK constraint and partial indexes:

```elixir
defmodule MyApp.Repo.Migrations.AddCartItemExclusiveArcs do
  use Ecto.Migration

  def up, do: AshExclusiveArc.Migration.up(MyApp.CartItem)
  def down, do: AshExclusiveArc.Migration.down(MyApp.CartItem)
end
```

## Create records

```elixir
# Set the FK directly in the create action
MyApp.CartItem
|> Ash.Changeset.for_create(:create, %{
  product_variant_id: variant.id,
  quantity: 2
})
|> Ash.create!()

# Or use the set/4 helper
MyApp.CartItem
|> Ash.Changeset.for_create(:create, %{quantity: 2})
|> AshExclusiveArc.set(:purchasable, :product_variant, variant.id)
|> Ash.create!()
```

## Query the arc

```elixir
item = Ash.get!(MyApp.CartItem, item_id, load: [:product_variant, :subscription_plan])

AshExclusiveArc.type(item, :purchasable)
#=> :product_variant

AshExclusiveArc.get(item, :purchasable)
#=> {:ok, {:product_variant, %MyApp.ProductVariant{...}}}
```
