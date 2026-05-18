defmodule AshExclusiveArc.SnapshotTest do
  use ExUnit.Case

  alias AshExclusiveArc.Snapshot
  alias AshExclusiveArc.Test.CartItem

  describe "build/1" do
    test "produces a snapshot map with all arcs from the resource" do
      snapshot = Snapshot.build(CartItem)

      assert snapshot.resource == "Elixir.AshExclusiveArc.Test.CartItem"
      assert snapshot.table == "cart_items"
      assert snapshot.snapshot_version == 1
      assert length(snapshot.arcs) == 2

      arc_names = snapshot.arcs |> Enum.map(& &1.name) |> Enum.sort()
      assert arc_names == [:owner, :purchasable]
    end

    test "snapshot arcs include references with attribute names" do
      snapshot = Snapshot.build(CartItem)
      purchasable = Enum.find(snapshot.arcs, &(&1.name == :purchasable))

      assert purchasable.referential_integrity == true

      ref_names = purchasable.references |> Enum.map(& &1.name) |> Enum.sort()
      assert ref_names == [:product, :subscription_plan]

      product_ref = Enum.find(purchasable.references, &(&1.name == :product))
      assert product_ref.attribute_name == :product_id
      assert product_ref.destination == "Elixir.AshExclusiveArc.Test.Product"
    end
  end

  describe "encode/1 and decode/1 round trip" do
    test "preserves all snapshot fields" do
      snapshot = Snapshot.build(CartItem)
      encoded = Snapshot.encode(snapshot)

      assert is_binary(encoded)
      assert String.contains?(encoded, "cart_items")
      assert String.contains?(encoded, "purchasable")

      {:ok, decoded} = Snapshot.decode(encoded)
      assert decoded == snapshot
    end

    test "encode emits stable, pretty-printed JSON for diff-friendliness" do
      snapshot = Snapshot.build(CartItem)
      encoded = Snapshot.encode(snapshot)

      # Pretty-printed: contains newlines between top-level keys
      assert String.contains?(encoded, "\n")
      # Arcs are sorted by name for stable diffs
      owner_idx = :binary.match(encoded, "\"owner\"") |> elem(0)
      purchasable_idx = :binary.match(encoded, "\"purchasable\"") |> elem(0)
      assert owner_idx < purchasable_idx
    end
  end

  describe "diff/2" do
    test "returns :no_changes when snapshots are equal" do
      snapshot = Snapshot.build(CartItem)
      assert Snapshot.diff(snapshot, snapshot) == :no_changes
    end

    test "detects removed arcs" do
      new_snapshot = Snapshot.build(CartItem)
      old_snapshot = put_in(new_snapshot.arcs, [])

      assert %{added: added, removed: removed, changed: changed} =
               Snapshot.diff(old_snapshot, new_snapshot)

      added_names = Enum.map(added, & &1.name) |> Enum.sort()
      assert added_names == [:owner, :purchasable]
      assert removed == []
      assert changed == []
    end

    test "detects added arcs" do
      old_snapshot = Snapshot.build(CartItem)
      new_snapshot = put_in(old_snapshot.arcs, [])

      assert %{added: added, removed: removed, changed: changed} =
               Snapshot.diff(old_snapshot, new_snapshot)

      removed_names = Enum.map(removed, & &1.name) |> Enum.sort()
      assert removed_names == [:owner, :purchasable]
      assert added == []
      assert changed == []
    end

    test "detects changed arcs (e.g. reference added)" do
      old_snapshot = Snapshot.build(CartItem)

      new_snapshot =
        update_in(old_snapshot.arcs, fn arcs ->
          Enum.map(arcs, fn
            %{name: :purchasable} = arc ->
              new_ref = %{
                name: :extra_thing,
                destination: "Elixir.AshExclusiveArc.Test.Product",
                attribute_name: :extra_thing_id,
                attribute_type: :uuid
              }

              %{arc | references: arc.references ++ [new_ref]}

            arc ->
              arc
          end)
        end)

      assert %{changed: [changed_arc]} = Snapshot.diff(old_snapshot, new_snapshot)
      assert changed_arc.name == :purchasable
    end
  end

  describe "up_statements/2" do
    test "produces the same SQL the live Migration module would for the same resource" do
      snapshot = Snapshot.build(CartItem)

      snapshot_statements = Snapshot.up_statements(snapshot)
      live_statements = AshExclusiveArc.Migration.up_statements(CartItem)

      assert Enum.sort(snapshot_statements) == Enum.sort(live_statements)
    end

    test "filtering by arc_name limits output" do
      snapshot = Snapshot.build(CartItem)

      filtered = Snapshot.up_statements(snapshot, :purchasable)
      assert Enum.any?(filtered, &String.contains?(&1, "purchasable"))
      refute Enum.any?(filtered, &String.contains?(&1, "owner"))
    end
  end

  describe "down_statements/2" do
    test "produces matching DROP statements for the snapshot" do
      snapshot = Snapshot.build(CartItem)

      statements = Snapshot.down_statements(snapshot)

      assert Enum.any?(statements, &String.contains?(&1, "DROP CONSTRAINT"))
      assert Enum.any?(statements, &String.contains?(&1, "DROP INDEX"))
    end
  end

  describe "read/1 and write/2" do
    @tag :tmp_dir
    test "round-trip via the file system", %{tmp_dir: tmp_dir} do
      snapshot = Snapshot.build(CartItem)
      path = Path.join(tmp_dir, "cart_items.json")

      assert :ok = Snapshot.write(path, snapshot)
      assert {:ok, ^snapshot} = Snapshot.read(path)
    end

    @tag :tmp_dir
    test "read/1 returns {:error, :enoent} when file is missing", %{tmp_dir: tmp_dir} do
      assert {:error, :enoent} = Snapshot.read(Path.join(tmp_dir, "missing.json"))
    end
  end
end
