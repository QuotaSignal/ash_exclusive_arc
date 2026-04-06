defmodule AshExclusiveArc.RepoCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias AshExclusiveArc.TestRepo
    end
  end

  setup tags do
    :ok = Sandbox.checkout(AshExclusiveArc.TestRepo)

    unless tags[:async] do
      Sandbox.mode(AshExclusiveArc.TestRepo, {:shared, self()})
    end

    :ok
  end
end
