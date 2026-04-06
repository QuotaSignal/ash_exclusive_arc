defmodule AshExclusiveArc.Test.Product do
  use Ash.Resource,
    domain: AshExclusiveArc.Test.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "products"
    repo AshExclusiveArc.TestRepo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
  end
end
