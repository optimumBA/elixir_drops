defmodule ElixirDrops.DropsTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop

  @invalid_attrs %{title: nil, body: nil}
  @valid_attrs %{title: "some title", body: "some body"}

  defp create_drops_setup(_attrs) do
    user = user_fixture()
    drop = drop_fixture(user)

    %{drop: drop, user: user}
  end

  describe "list_drops" do
    setup [:create_drops_setup]

    test "returns all drops with pagiation metadata when no filter is passed" do
      assert %{current_page: 1, entries: [drop], total_pages: 1} = Drops.list_drops(10)

      assert Ecto.assoc_loaded?(drop.user)
    end

    test "returns all drops filtered by user_id", %{user: user} do
      assert %{current_page: 1, entries: [drop], total_pages: 1} =
               Drops.list_drops(10, %{user_id: user.id})

      assert Ecto.assoc_loaded?(drop.user)
    end

    test "returns empty list when no drops are found" do
      non_existing_user_id = Ecto.UUID.generate()

      assert %{current_page: 1, entries: [], total_pages: 0} =
               Drops.list_drops(10, %{user_id: non_existing_user_id})
    end
  end

  describe "create_or_update_drop/3" do
    setup [:create_drops_setup]

    test "creates a drop given valid data", %{user: user} do
      assert {:ok, %Drop{} = drop} = Drops.create_or_update_drop(%Drop{}, user, @valid_attrs)

      assert drop.body == @valid_attrs.body
      assert drop.title == @valid_attrs.title
      assert drop.user_id == user.id
    end

    test "returns an error if data is invalid", %{user: user} do
      assert {:error, %Ecto.Changeset{}} =
               Drops.create_or_update_drop(%Drop{}, user, @invalid_attrs)
    end

    test "updates an existing drop", %{drop: drop, user: user} do
      assert {:ok, %Drop{} = drop} =
               Drops.create_or_update_drop(drop, user, %{
                 body: "Updated body",
                 title: "Updated title"
               })

      assert drop.body == "Updated body"
      assert drop.title == "Updated title"
    end
  end

  describe "get_drop/1" do
    setup [:create_drops_setup]

    test "returns the drop with given id", %{drop: drop} do
      assert %Drop{} = drop = Drops.get_drop(drop.id)
      assert Ecto.assoc_loaded?(drop.user)
    end

    test "returns nil if the drop does not exist" do
      non_existent_id = Ecto.UUID.generate()

      refute Drops.get_drop(non_existent_id)
    end
  end

  describe "change_drop/1" do
    setup [:create_drops_setup]

    test "returns a valid drop changeset", %{drop: drop} do
      assert %Ecto.Changeset{} = changeset = Drops.change_drop(drop)

      assert changeset.valid?
    end

    test "returns error changeset if data is invalid" do
      assert %Ecto.Changeset{} = changeset = Drops.change_drop(%Drop{}, @invalid_attrs)

      assert %{
               body: ["can't be blank"],
               title: [
                 "can't be blank"
               ]
             } = errors_on(changeset)
    end
  end
end
