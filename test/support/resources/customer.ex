defmodule AshExclusiveArc.Test.Customer do
  use Ash.Resource,
    domain: AshExclusiveArc.Test.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "customers"
    repo AshExclusiveArc.TestRepo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false, public?: true
  end
end
