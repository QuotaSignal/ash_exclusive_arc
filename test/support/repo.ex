defmodule AshExclusiveArc.TestRepo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :ash_exclusive_arc

  def installed_extensions do
    ["ash-functions"]
  end

  def all_tenants, do: []

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
