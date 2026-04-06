spark_locals_without_parens = [
  arc: 1,
  arc: 2,
  belongs_to: 2,
  belongs_to: 3,
  referential_integrity: 1,
  archive_aware: 1,
  archive_column: 1,
  attribute_type: 1,
  define_attribute: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: spark_locals_without_parens,
  import_deps: [:ash, :spark],
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
