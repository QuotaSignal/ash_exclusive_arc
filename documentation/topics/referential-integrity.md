# Referential Integrity

AshExclusiveArc generates database-level constraints by default. This page explains what gets generated, how to opt out, and how it integrates with soft-delete via `ash_archival`.

## What Gets Generated

For each arc with referential integrity enabled:

### CHECK Constraint

Ensures exactly one FK in the arc is non-null:

```sql
ALTER TABLE cart_items ADD CONSTRAINT cart_items_purchasable_exclusive_arc
CHECK (
  (CASE WHEN product_variant_id IS NOT NULL THEN 1 ELSE 0 END) +
  (CASE WHEN subscription_plan_id IS NOT NULL THEN 1 ELSE 0 END) = 1
)
```

### Partial Unique Indexes

One index per FK column, scoped to non-null values:

```sql
CREATE INDEX cart_items_product_variant_id_exclusive_index
  ON cart_items (product_variant_id)
  WHERE product_variant_id IS NOT NULL
```

## Opting Out

Set `referential_integrity: false` at the section level or per-arc:

```elixir
# Per-arc
exclusive_arc do
  arc :owner, referential_integrity: false do
    belongs_to :customer, MyApp.Customer
  end
end

# Section-wide
exclusive_arc referential_integrity: false do
  arc :purchasable do
    belongs_to :product, MyApp.Product
  end
end
```

When opted out:
- No CHECK constraint or indexes are generated
- The Ash-layer changeset validation still runs
- FK columns and `belongs_to` relationships are still created

Use cases for opting out:
- Cross-database references where FK constraints can't span databases
- Resources without AshPostgres (ETS, Mnesia, custom data layers)
- Legacy schemas where adding constraints isn't feasible
- Intermediate migration steps

## AshArchival Integration

When the source resource (the one with the arc) uses `ash_archival` for soft-deletes, partial unique indexes automatically exclude archived records:

```sql
CREATE INDEX cart_items_product_variant_id_exclusive_index
  ON cart_items (product_variant_id)
  WHERE product_variant_id IS NOT NULL
  AND archived_at IS NULL
```

This is detected automatically when `archive_aware: true` (the default). The extension looks for an `archived_at` attribute on the resource.

### Manual Configuration

Override the archive column name:

```elixir
exclusive_arc do
  arc :purchasable, archive_column: :deleted_at do
    belongs_to :product, MyApp.Product
  end
end
```

Disable archive-aware indexes for a specific arc:

```elixir
exclusive_arc do
  arc :purchasable, archive_aware: false do
    belongs_to :product, MyApp.Product
  end
end
```
