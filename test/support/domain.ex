defmodule AshExclusiveArc.Test.Domain do
  use Ash.Domain

  resources do
    resource AshExclusiveArc.Test.Product
    resource AshExclusiveArc.Test.SubscriptionPlan
    resource AshExclusiveArc.Test.Customer
    resource AshExclusiveArc.Test.GuestSession
    resource AshExclusiveArc.Test.CartItem
  end
end
