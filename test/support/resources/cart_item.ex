defmodule AshExclusiveArc.Test.CartItem do
  use Ash.Resource,
    domain: AshExclusiveArc.Test.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshExclusiveArc.Resource]

  postgres do
    table "cart_items"
    repo(AshExclusiveArc.TestRepo)
  end

  exclusive_arc do
    arc :purchasable do
      belongs_to :product, AshExclusiveArc.Test.Product
      belongs_to :subscription_plan, AshExclusiveArc.Test.SubscriptionPlan
    end

    arc :owner do
      belongs_to :customer, AshExclusiveArc.Test.Customer
      belongs_to :guest_session, AshExclusiveArc.Test.GuestSession
    end
  end

  actions do
    defaults [:read, :destroy, create: :*, update: :*]
  end

  attributes do
    uuid_primary_key :id
    attribute :quantity, :integer, allow_nil?: false, default: 1, public?: true
  end
end
