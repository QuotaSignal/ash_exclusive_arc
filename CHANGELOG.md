# Changelog

## Unreleased

### Added

- `mix ash_exclusive_arc.gen.migration <Resource> --repo <Repo>` task that
  diffs the resource's arc DSL against a JSON snapshot and emits an
  `Ecto.Migration` with the resulting CHECK + partial unique index SQL embedded
  inline. Snapshots are pretty-printed and committed to version control for
  diff-friendly review of arc-shape changes.
- `AshExclusiveArc.Snapshot` — pure module for building, encoding, decoding,
  diffing, and producing SQL statements from a snapshot.
- `AshExclusiveArc.Migration.Generator` — engine behind the mix task; usable
  programmatically with `generate/2` + `write_result/1` for custom workflows
  (e.g. CI guardrails that fail when arc DSL drifts from the committed snapshot).

## 0.1.0

### Added

- Initial release
- `exclusive_arc` DSL section with `arc` and `belongs_to` entities
- Compile-time transformer that generates nullable FK attributes and `belongs_to` relationships
- `ValidateArc` change ensuring exactly one FK per arc is set (Ash-layer validation)
- Referential integrity support: CHECK constraint and partial unique index SQL generation
- `ash_archival` integration: partial indexes automatically exclude archived records
- `referential_integrity` option (section-level and per-arc) to opt out of DB constraints
- `AshExclusiveArc.Migration` helpers for executing constraint SQL in migrations
- Public API: `type/2`, `get/2`, `set/4`
- Compile-time verifiers for duplicate arc/reference names
