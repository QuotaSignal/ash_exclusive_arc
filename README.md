# AshExclusiveArc

An [Ash](https://hexdocs.pm/ash) extension implementing the [exclusive belongs-to (exclusive arc)](https://hashrocket.com/blog/posts/modeling-polymorphic-associations-in-a-relational-database) pattern for referential-integrity-safe polymorphic relationships.

Instead of `resource_id` + `resource_type` string pairs (which lack foreign key constraints and allow orphaned records), this extension creates multiple nullable foreign keys with a database CHECK constraint ensuring exactly one is non-null.

## Installation

```elixir
def deps do
  [
    {:ash_exclusive_arc, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
defmodule MyApp.CartItem do
  use Ash.Resource,
    extensions: [AshExclusiveArc.Resource]

  exclusive_arc do
    arc :purchasable do
      belongs_to :product_variant, MyApp.ProductVariant
      belongs_to :subscription_plan, MyApp.SubscriptionPlan
    end

    arc :owner do
      belongs_to :customer, MyApp.Customer
      belongs_to :guest_session, MyApp.GuestSession
    end
  end
end
```

This generates:

- Nullable FK attributes (`product_variant_id`, `subscription_plan_id`, etc.)
- `belongs_to` relationships for each reference
- A changeset validation ensuring exactly one FK per arc is set
- SQL for a CHECK constraint and partial unique indexes (via `AshExclusiveArc.Migration`)

## Referential Integrity

Database-level constraints are enabled by default. Opt out per-arc or globally for
cross-database references, non-Postgres data layers, or Ash-only validation:

```elixir
exclusive_arc do
  # This arc gets full DB constraints (default)
  arc :purchasable do
    belongs_to :product_variant, MyApp.ProductVariant
    belongs_to :subscription_plan, MyApp.SubscriptionPlan
  end

  # This arc uses Ash-layer validation only
  arc :owner, referential_integrity: false do
    belongs_to :customer, MyApp.Customer
    belongs_to :external_account, MyApp.ExternalAccount
  end
end
```

## Migrations

After running `mix ash_postgres.generate_migrations`, add a separate migration for the constraints:

```elixir
defmodule MyApp.Repo.Migrations.AddExclusiveArcConstraints do
  use Ecto.Migration

  def up, do: AshExclusiveArc.Migration.up(MyApp.CartItem)
  def down, do: AshExclusiveArc.Migration.down(MyApp.CartItem)
end
```

## AshArchival Support

When the source resource uses `ash_archival`, partial unique indexes automatically
exclude archived records (`WHERE ... AND archived_at IS NULL`).

## Public API

```elixir
# Which type is set?
AshExclusiveArc.type(cart_item, :purchasable)
#=> :product_variant

# Get the loaded association
AshExclusiveArc.get(cart_item, :purchasable)
#=> {:ok, {:product_variant, %MyApp.ProductVariant{...}}}

# Set on a changeset (nils all other FKs in the arc)
changeset |> AshExclusiveArc.set(:purchasable, :product_variant, variant_id)
```

## Documentation

- [Get Started](documentation/tutorials/get-started.md)
- [How It Works](documentation/topics/how-it-works.md)
- [Referential Integrity](documentation/topics/referential-integrity.md)
