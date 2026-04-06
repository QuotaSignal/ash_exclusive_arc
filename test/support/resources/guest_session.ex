defmodule AshExclusiveArc.Test.GuestSession do
  use Ash.Resource,
    domain: AshExclusiveArc.Test.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "guest_sessions"
    repo AshExclusiveArc.TestRepo
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :session_token, :string, allow_nil?: false, public?: true
  end
end
