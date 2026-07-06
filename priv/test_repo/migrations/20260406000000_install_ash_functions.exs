defmodule AshExclusiveArc.TestRepo.Migrations.InstallAshFunctions do
  @moduledoc """
  Installs the `ash-functions` extension helpers (declared in
  `AshExclusiveArc.TestRepo.installed_extensions/0`) so that atomic
  validations — which compile to `ash_raise_error(...)` calls in generated
  SQL — can run against the test repo.
  """
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION ash_raise_error(json_data jsonb)
    RETURNS BOOLEAN AS $$
    BEGIN
        RAISE EXCEPTION 'ash_error: %', json_data::text;
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql
    STABLE
    SET search_path = '';
    """)

    execute("""
    CREATE OR REPLACE FUNCTION ash_raise_error(json_data jsonb, type_signal ANYCOMPATIBLE)
    RETURNS ANYCOMPATIBLE AS $$
    BEGIN
        RAISE EXCEPTION 'ash_error: %', json_data::text;
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql
    STABLE
    SET search_path = '';
    """)
  end

  def down do
    execute("DROP FUNCTION IF EXISTS ash_raise_error(jsonb, ANYCOMPATIBLE)")
    execute("DROP FUNCTION IF EXISTS ash_raise_error(jsonb)")
  end
end
