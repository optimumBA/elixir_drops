defmodule ElixirDrops.DropsTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  @invalid_attrs %{title: nil, body: nil}
  @valid_attrs %{title: "some title", body: "some body"}

  defp create_drops_setup(_attrs) do
    user = user_fixture()
    drop = drop_fixture(user)

    %{drop: drop, user: user}
  end

  describe "list_drops/0" do
    setup :create_drops_setup

    test "list_drops/0 returns all drops" do
      assert [drop] = Drops.list_drops()

      assert Ecto.assoc_loaded?(drop.user)
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

  describe "get_user_drops/1" do
    setup [:create_drops_setup]

    test "returns a list of user's drops", %{user: user} do
      assert [drop] = Drops.get_user_drops(user.id)
      assert Ecto.assoc_loaded?(drop.user)
    end
  end

  describe "list_older_drops/2" do
    test "returns a list of drops created before a drop" do
      user = user_fixture()

      drop_1 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(120)

      drop_2 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(240)

      _drop_3 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(360)

      _drop_4 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(480)

      assert [drop] = Drops.list_older_drops(drop_2)
      assert drop.id == drop_1.id
      assert Ecto.assoc_loaded?(drop.user)
    end

    test "returns an empty list if there are no older drops" do
      user = user_fixture()

      _drop_1 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(120)

      drop_2 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(100)

      assert drop_2
             |> Drops.list_older_drops()
             |> Enum.empty?()
    end
  end

  describe "list_newer_drops/2" do
    test "returns a list of drops created after a drop" do
      user = user_fixture()

      _drop_1 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(120)

      drop_2 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(240)

      drop_3 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(360)

      assert [drop] = Drops.list_newer_drops(drop_2)
      assert drop.id == drop_3.id
      assert Ecto.assoc_loaded?(drop.user)
    end

    test "returns an empty list if there are no newer drops" do
      user = user_fixture()

      drop_1 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(120)

      _drop_2 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(100)

      assert drop_1
             |> Drops.list_newer_drops()
             |> Enum.empty?()
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

  defp time_before(amount_to_add) do
    DateTime.utc_now()
    |> DateTime.add(amount_to_add)
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
  end

  defp update_drop_inserted_at(drop, time_to_add) do
    {:ok, updated_drop} =
      drop
      |> Ecto.Changeset.change(%{inserted_at: time_before(time_to_add)})
      |> Repo.update()

    updated_drop
  end
end
