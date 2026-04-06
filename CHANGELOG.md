# Changelog

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
