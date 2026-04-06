# How AshExclusiveArc Works

## The Problem

Polymorphic relationships in relational databases are commonly modeled with a `resource_id` + `resource_type` pair:

```
cart_items
  purchasable_id   UUID
  purchasable_type VARCHAR  -- "ProductVariant" or "SubscriptionPlan"
```

This approach has serious drawbacks:

- No foreign key constraints (the database can't verify the referenced record exists)
- Orphaned records when referenced records are deleted
- No cascade deletes
- The `_type` column is a string that can hold any value

## The Exclusive Arc Pattern

AshExclusiveArc uses the exclusive belongs-to pattern instead. For each arc, it creates multiple nullable FK columns with a CHECK constraint ensuring exactly one is non-null:

```
cart_items
  product_variant_id    UUID REFERENCES product_variants(id)
  subscription_plan_id  UUID REFERENCES subscription_plans(id)

  CONSTRAINT cart_items_purchasable_exclusive_arc
  CHECK (
    (CASE WHEN product_variant_id IS NOT NULL THEN 1 ELSE 0 END) +
    (CASE WHEN subscription_plan_id IS NOT NULL THEN 1 ELSE 0 END) = 1
  )
```

This gives you:

- Real FK constraints with referential integrity
- No orphaned records
- Database-level enforcement that exactly one association is set
- Efficient NULL storage in PostgreSQL (1 bit per nullable column)

## What the Extension Generates

When you write:

```elixir
exclusive_arc do
  arc :purchasable do
    belongs_to :product_variant, MyApp.ProductVariant
    belongs_to :subscription_plan, MyApp.SubscriptionPlan
  end
end
```

The compile-time transformer adds to your resource:

1. **Attributes**: `product_variant_id` and `subscription_plan_id` (nullable, writable, public)
2. **Relationships**: `belongs_to :product_variant` and `belongs_to :subscription_plan`
3. **Changeset validation**: A `before_action` change that verifies exactly one FK is non-null
4. **Persisted constraint info**: SQL metadata for `AshExclusiveArc.Migration` to generate CHECK constraints and partial unique indexes

## Two Layers of Validation

- **Ash layer** (always active): The `ValidateArc` change runs on every create/update, rejecting changesets where zero or multiple FKs are set. This provides clear error messages.
- **Database layer** (opt-in, default on): The CHECK constraint rejects invalid rows at the database level, catching bugs in code that bypasses Ash actions.
