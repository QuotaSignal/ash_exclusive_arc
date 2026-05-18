defmodule AshExclusiveArc.Migration.GeneratorTest do
  use ExUnit.Case

  alias AshExclusiveArc.Migration.Generator
  alias AshExclusiveArc.Snapshot
  alias AshExclusiveArc.Test.CartItem

  describe "generate/2 on a fresh resource (no previous snapshot)" do
    @tag :tmp_dir
    test "returns an :initial result with up/down SQL and a derived migration name", %{
      tmp_dir: tmp_dir
    } do
      result =
        Generator.generate(CartItem,
          repo: AshExclusiveArc.TestRepo,
          migrations_path: Path.join(tmp_dir, "migrations"),
          snapshot_path: Path.join([tmp_dir, "snapshots", "cart_items.json"])
        )

      assert result.status == :initial

      assert Path.basename(result.migration_path) =~
               ~r/^\d{14}_add_exclusive_arcs_cart_items\.exs$/

      assert result.migration_contents =~ "defmodule"
      assert result.migration_contents =~ "use Ecto.Migration"
      assert result.migration_contents =~ "def up"
      assert result.migration_contents =~ "def down"
      assert result.migration_contents =~ "cart_items_purchasable_exclusive_arc"
      assert result.migration_contents =~ "DROP CONSTRAINT IF EXISTS"
    end

    @tag :tmp_dir
    test "honours an explicit :name override", %{tmp_dir: tmp_dir} do
      result =
        Generator.generate(CartItem,
          repo: AshExclusiveArc.TestRepo,
          migrations_path: Path.join(tmp_dir, "migrations"),
          snapshot_path: Path.join([tmp_dir, "snapshots", "cart_items.json"]),
          name: "custom_constraint_migration"
        )

      assert Path.basename(result.migration_path) =~ ~r/^\d{14}_custom_constraint_migration\.exs$/
    end
  end

  describe "generate/2 with an unchanged snapshot" do
    @tag :tmp_dir
    test "returns :no_changes and does not produce a migration", %{tmp_dir: tmp_dir} do
      snapshot_path = Path.join([tmp_dir, "snapshots", "cart_items.json"])
      :ok = Snapshot.write(snapshot_path, Snapshot.build(CartItem))

      result =
        Generator.generate(CartItem,
          repo: AshExclusiveArc.TestRepo,
          migrations_path: Path.join(tmp_dir, "migrations"),
          snapshot_path: snapshot_path
        )

      assert result.status == :no_changes
      assert result.migration_path == nil
      assert result.migration_contents == nil
    end
  end

  describe "generate/2 with a divergent snapshot" do
    @tag :tmp_dir
    test "emits an :update migration that drops the old shape and adds the new", %{
      tmp_dir: tmp_dir
    } do
      # Persist an "old" snapshot with a different shape (one branch removed
      # from :purchasable) so the diff sees the resource as having added that
      # branch.
      current = Snapshot.build(CartItem)

      old =
        update_in(current.arcs, fn arcs ->
          Enum.map(arcs, fn
            %{name: :purchasable} = arc ->
              %{arc | references: Enum.reject(arc.references, &(&1.name == :subscription_plan))}

            arc ->
              arc
          end)
        end)

      snapshot_path = Path.join([tmp_dir, "snapshots", "cart_items.json"])
      :ok = Snapshot.write(snapshot_path, old)

      result =
        Generator.generate(CartItem,
          repo: AshExclusiveArc.TestRepo,
          migrations_path: Path.join(tmp_dir, "migrations"),
          snapshot_path: snapshot_path
        )

      assert result.status == :update

      assert Path.basename(result.migration_path) =~
               ~r/^\d{14}_update_exclusive_arcs_cart_items\.exs$/

      # The diff is :purchasable changed, so the migration should drop the old
      # purchasable check and add the new one. Owner is untouched.
      assert result.migration_contents =~
               "DROP CONSTRAINT IF EXISTS cart_items_purchasable_exclusive_arc"

      assert result.migration_contents =~ "ADD CONSTRAINT cart_items_purchasable_exclusive_arc"
      refute result.migration_contents =~ "cart_items_owner_exclusive_arc"
    end
  end

  describe "write_result/1" do
    @tag :tmp_dir
    test "writes both the migration and the snapshot to disk", %{tmp_dir: tmp_dir} do
      migrations_path = Path.join(tmp_dir, "migrations")
      snapshot_path = Path.join([tmp_dir, "snapshots", "cart_items.json"])

      result =
        Generator.generate(CartItem,
          repo: AshExclusiveArc.TestRepo,
          migrations_path: migrations_path,
          snapshot_path: snapshot_path
        )

      assert :ok = Generator.write_result(result)

      assert File.exists?(result.migration_path)
      assert File.exists?(snapshot_path)

      {:ok, written} = Snapshot.read(snapshot_path)
      assert written == result.new_snapshot
    end

    @tag :tmp_dir
    test "is a no-op when status is :no_changes", %{tmp_dir: tmp_dir} do
      snapshot_path = Path.join([tmp_dir, "snapshots", "cart_items.json"])
      :ok = Snapshot.write(snapshot_path, Snapshot.build(CartItem))

      result =
        Generator.generate(CartItem,
          repo: AshExclusiveArc.TestRepo,
          migrations_path: Path.join(tmp_dir, "migrations"),
          snapshot_path: snapshot_path
        )

      assert :ok = Generator.write_result(result)
      refute File.exists?(Path.join(tmp_dir, "migrations"))
    end
  end

  describe "module_name_for/2" do
    test "derives a sensible Ecto.Migration module name" do
      assert Generator.module_name_for(AshExclusiveArc.TestRepo, "add_exclusive_arcs_cart_items") ==
               "AshExclusiveArc.TestRepo.Migrations.AddExclusiveArcsCartItems"
    end
  end
end
