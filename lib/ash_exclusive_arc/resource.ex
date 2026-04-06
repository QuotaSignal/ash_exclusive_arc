defmodule AshExclusiveArc.Resource do
  @moduledoc """
  An Ash resource extension implementing the exclusive belongs-to (exclusive arc) pattern.

  This provides referential-integrity-safe polymorphic relationships using multiple
  nullable foreign keys with a CHECK constraint ensuring exactly one is non-null.

  ## Usage

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

  ## Referential Integrity

  By default, the extension generates database-level constraints (CHECK constraint,
  foreign keys, partial unique indexes). This can be opted out per-arc or globally:

      exclusive_arc do
        arc :owner, referential_integrity: false do
          belongs_to :customer, MyApp.Customer
        end
      end

  ## Soft-Delete (AshArchival) Support

  When the source resource uses `ash_archival`, partial unique indexes automatically
  exclude archived records. This is detected automatically but can be configured:

      exclusive_arc do
        arc :purchasable, archive_column: :archived_at do
          belongs_to :product_variant, MyApp.ProductVariant
        end
      end
  """

  @arc_reference %Spark.Dsl.Entity{
    name: :belongs_to,
    describe: "Declares one possible target for this exclusive arc.",
    target: AshExclusiveArc.ArcReference,
    args: [:name, :destination],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of this reference (used as the relationship name)."
      ],
      destination: [
        type: :atom,
        required: true,
        doc: "The destination resource module."
      ],
      attribute_type: [
        type: :any,
        default: :uuid,
        doc: "The type of the foreign key attribute."
      ],
      define_attribute: [
        type: :boolean,
        default: true,
        doc:
          "Whether to define the foreign key attribute. Set to false if you define it yourself."
      ]
    ]
  }

  @arc %Spark.Dsl.Entity{
    name: :arc,
    describe: """
    Defines an exclusive arc — a group of mutually exclusive belongs_to relationships
    where exactly one must be set at any time.
    """,
    target: AshExclusiveArc.Arc,
    args: [:name],
    entities: [references: [@arc_reference]],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of this exclusive arc (e.g., :purchasable, :owner)."
      ],
      referential_integrity: [
        type: :boolean,
        doc: """
        Whether to generate database-level constraints (CHECK constraint, foreign keys,
        partial unique indexes). Defaults to the section-level setting.

        Set to `false` for cross-database references, resources without AshPostgres,
        or when you want Ash-layer validation only.
        """
      ],
      archive_aware: [
        type: :boolean,
        default: true,
        doc: """
        Whether partial unique indexes should exclude archived records when the source
        resource uses `ash_archival`. Detected automatically when true.
        """
      ],
      archive_column: [
        type: :atom,
        doc: """
        Override the archive column name for partial index conditions.
        Detected automatically from `ash_archival` config when nil.
        """
      ]
    ]
  }

  @exclusive_arc %Spark.Dsl.Section{
    name: :exclusive_arc,
    describe: """
    Configures exclusive arc (exclusive belongs-to) relationships on this resource.
    Each arc defines a group of mutually exclusive belongs_to relationships where
    exactly one must be non-null.
    """,
    entities: [@arc],
    schema: [
      referential_integrity: [
        type: :boolean,
        default: true,
        doc: """
        Default referential integrity setting for all arcs in this section.
        When true, generates CHECK constraints, foreign keys, and partial unique indexes.
        When false, only Ash-layer validation is used.
        """
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@exclusive_arc],
    transformers: [AshExclusiveArc.Transformers.SetupArcs],
    verifiers: [AshExclusiveArc.Verifiers.ValidateArcs]
end
