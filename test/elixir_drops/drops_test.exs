defmodule ElixirDrops.DropsTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.Tag

  @invalid_attrs %{body: nil, tags: nil, title: nil}
  @valid_attrs %{body: "some body", tags: ["tag3", "tag4"], title: "some title"}

  defp create_drops_setup(_attrs) do
    user = user_fixture()
    drop = drop_fixture(user)

    %{drop: drop, user: user}
  end

  describe "list_drops/2" do
    test "returns a list of drops with a given tag" do
      %{drop: drop, user: user} = create_drops_setup(%{})

      _drop_2 =
        drop_fixture(
          %Drop{},
          user,
          %{title: "Drop 2", body: "Body for drop 2", tags: ["drop2", "tag"]}
        )

      assert [tagged_drop] = Drops.list_drops(%{tag: "tag1"})

      assert tagged_drop.id == drop.id
      assert Ecto.assoc_loaded?(tagged_drop.user)
      assert Ecto.assoc_loaded?(tagged_drop.tags)
    end

    test "returns an empty list if no drops match the given tag" do
      create_drops_setup(%{})

      drops_with_tag = Drops.list_drops(%{tag: "non-existent"})

      assert Enum.empty?(drops_with_tag)
    end

    test "returns a list of all drops when no filter is passed" do
      create_drops_setup(%{})

      assert [drop] = Drops.list_drops()

      assert Ecto.assoc_loaded?(drop.user)
      assert Ecto.assoc_loaded?(drop.tags)
    end

    test "can filter drops belonging to a user" do
      %{drop: drop, user: user} = create_drops_setup(%{})

      user_2 =
        user_fixture(%{
          avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
          email: "user2@mail.com",
          github_id: 12_345,
          github_username: "github_username",
          name: "some_name"
        })

      drop_fixture(%Drop{}, user_2, %{
        body: "Body for drop 2",
        tags: ["tag4", "tag5"],
        title: "Drop 2"
      })

      assert [user_drop] = Drops.list_drops(%{user_id: user.id})

      assert drop.id == user_drop.id
      assert Ecto.assoc_loaded?(user_drop.user)
      assert Ecto.assoc_loaded?(user_drop.tags)
    end

    test "returns empty list when a user has no drops" do
      non_existing_user_id = Ecto.UUID.generate()

      assert [] = Drops.list_drops(%{user_id: non_existing_user_id})
    end

    test "can filter drops older than a given drop sorted by inserted_at" do
      user = user_fixture()

      [drop_1, drop_2, drop_3, _drop_4] =
        for drop <- 1..4 do
          %Drop{}
          |> drop_fixture(user)
          |> update_drop_inserted_at(drop * 120)
        end

      assert [older_drop_1, older_drop_2] = Drops.list_drops(%{older_than: drop_3})
      assert older_drop_1.id == drop_2.id
      assert older_drop_2.id == drop_1.id
      assert Ecto.assoc_loaded?(older_drop_1.user)
      assert Ecto.assoc_loaded?(older_drop_1.tags)
      assert Ecto.assoc_loaded?(older_drop_2.user)
      assert Ecto.assoc_loaded?(older_drop_2.tags)
    end

    test "returns an empty list if there are no drops older than a given drop" do
      user = user_fixture()

      [drop_1, _drop_2] =
        for drop <- 1..2 do
          %Drop{}
          |> drop_fixture(user)
          |> update_drop_inserted_at(drop * 120)
        end

      assert %{older_than: drop_1}
             |> Drops.list_drops()
             |> Enum.empty?()
    end

    test "can filter drops newer than a given drop sorted by inserted_at" do
      user = user_fixture()

      [_drop_1, drop_2, drop_3, drop_4] =
        for drop <- 1..4 do
          %Drop{}
          |> drop_fixture(user)
          |> update_drop_inserted_at(drop * 120)
        end

      assert [newer_drop_1, newer_drop_2] = Drops.list_drops(%{newer_than: drop_2})
      assert newer_drop_1.id == drop_4.id
      assert newer_drop_2.id == drop_3.id
      assert Ecto.assoc_loaded?(newer_drop_1.user)
      assert Ecto.assoc_loaded?(newer_drop_1.tags)
      assert Ecto.assoc_loaded?(newer_drop_2.user)
      assert Ecto.assoc_loaded?(newer_drop_2.tags)
    end

    test "returns an empty list if there are no newer drops" do
      user = user_fixture()

      [_drop_1, drop_2] =
        for drop <- 1..2 do
          %Drop{}
          |> drop_fixture(user)
          |> update_drop_inserted_at(drop * 120)
        end

      assert %{newer_than: drop_2}
             |> Drops.list_drops()
             |> Enum.empty?()
    end

    test "can filter drops by multiple parameters" do
      user = user_fixture()

      user_2 =
        user_fixture(%{
          avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
          email: "user2@mail.com",
          github_id: 12_345,
          github_username: "github_username",
          name: "some_name"
        })

      [drop_1, _drop_2, drop_3] =
        for drop <- 1..3 do
          %Drop{}
          |> drop_fixture(user, %{
            body: "Body for drop #{drop}",
            tags: ["drop#{drop}", "drop"],
            title: "Drop #{drop}"
          })
          |> update_drop_inserted_at(drop * 120)
        end

      for drop <- 1..3 do
        %Drop{}
        |> drop_fixture(user_2)
        |> update_drop_inserted_at(drop * 120)
      end

      assert [older_user_drop] =
               Drops.list_drops(%{user_id: user.id, older_than: drop_3, tag: "drop1"})

      assert older_user_drop.id == drop_1.id
      assert older_user_drop.user_id == user.id

      assert Ecto.assoc_loaded?(older_user_drop.user)
      assert Ecto.assoc_loaded?(older_user_drop.tags)
    end

    test "returns empty list for multiple filters whose conditions are not met" do
      user = user_fixture()

      user_2 =
        user_fixture(%{
          avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
          email: "user2@mail.com",
          github_id: 12_345,
          github_username: "github_username",
          name: "some_name"
        })

      _drop_1 =
        %Drop{}
        |> drop_fixture(user)
        |> update_drop_inserted_at(120)

      [_drop_2, drop_3] =
        for drop <- 1..2 do
          %Drop{}
          |> drop_fixture(user_2)
          |> update_drop_inserted_at(drop * 120)
        end

      assert [] == Drops.list_drops(%{user_id: user_2.id, newer_than: drop_3})
    end

    test "defaults to listing all drops if a non-existent filter is passed" do
      %{drop: drop} = create_drops_setup(%{})

      assert [result_drop] = Drops.list_drops(%{unknown_filter: "unknown_filter"})
      assert drop.id == result_drop.id
    end
  end

  describe "create_drop/3" do
    test "creates a drop given valid data" do
      user = user_fixture()
      assert {:ok, %Drop{} = drop} = Drops.create_drop(%Drop{}, user, @valid_attrs)

      assert drop.body == @valid_attrs.body
      assert drop.title == @valid_attrs.title
      assert drop.user_id == user.id
      assert [%Tag{name: "tag3"}, %Tag{name: "tag4"}] = drop.tags
    end

    test "returns an error changeset if data is invalid" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Drops.create_drop(%Drop{}, user, @invalid_attrs)
    end

    test "returns an error changeset if a drop has less than 2 tags" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Drops.create_drop(%Drop{}, user, %{body: "body", title: "title", tags: ["tag1"]})

      assert %{
               tags: ["Should have at least 2 drops and at most 10 tags"]
             } = errors_on(changeset)
    end

    test "returns an error changeset for drop with more than 10 tags" do
      user = user_fixture()
      tags = Enum.map(1..12, &"tag#{&1}")

      assert {:error, %Ecto.Changeset{} = changeset} =
               Drops.create_drop(%Drop{}, user, %{body: "body", title: "title", tags: tags})

      assert %{
               tags: ["Should have at least 2 drops and at most 10 tags"]
             } = errors_on(changeset)
    end
  end

  describe "update_drop/3" do
    setup [:create_drops_setup]

    test "updates an existing drop", %{drop: drop, user: user} do
      assert {:ok, %Drop{} = drop} =
               Drops.update_drop(drop, user, %{
                 body: "Updated body",
                 tags: ["tag6", "tag7"],
                 title: "Updated title"
               })

      assert drop.body == "Updated body"
      assert drop.title == "Updated title"
      assert [%Tag{name: "tag6"}, %Tag{name: "tag7"}] = drop.tags
    end

    test "returns an error changeset if data is invalid", %{drop: drop, user: user} do
      assert {:error, %Ecto.Changeset{}} =
               Drops.update_drop(drop, user, @invalid_attrs)
    end

    test "returns an error changeset if the updated drop has less than 2 tags", %{
      drop: drop,
      user: user
    } do
      assert {:error, %Ecto.Changeset{} = changeset} =
               Drops.update_drop(drop, user, %{body: "body", title: "title", tags: ["tag1"]})

      assert %{
               tags: ["Should have at least 2 drops and at most 10 tags"]
             } = errors_on(changeset)
    end

    test "returns an error changeset if the updated drop has more than 10 tags", %{
      drop: drop,
      user: user
    } do
      tags = Enum.map(1..12, &"tag#{&1}")

      assert {:error, %Ecto.Changeset{} = changeset} =
               Drops.update_drop(drop, user, %{body: "body", title: "title", tags: tags})

      assert %{
               tags: ["Should have at least 2 drops and at most 10 tags"]
             } = errors_on(changeset)
    end
  end

  describe "get_drop/1" do
    setup [:create_drops_setup]

    test "returns the drop with given id", %{drop: drop} do
      assert %Drop{} = drop = Drops.get_drop(drop.id)
      assert Ecto.assoc_loaded?(drop.tags)
      assert Ecto.assoc_loaded?(drop.user)
    end

    test "returns nil if the drop does not exist" do
      non_existent_id = Ecto.UUID.generate()

      refute Drops.get_drop(non_existent_id)
    end
  end

  describe "get_tag_by_name/1" do
    setup [:create_drops_setup]

    test "returns the tag matching a given name" do
      assert [tag1, tag2] = Drops.get_tag_by_name("tag")

      assert tag1.name == "tag1"
      assert tag2.name == "tag2"
    end

    test "returns and empty list if no tag matches the given name" do
      assert [] = Drops.get_tag_by_name("non-existent")
    end
  end

  describe "change_drop/2" do
    setup [:create_drops_setup]

    test "returns a valid drop changeset", %{drop: drop} do
      assert %Ecto.Changeset{} = changeset = Drops.change_drop(drop)

      assert changeset.valid?
    end

    test "returns error changeset if data is invalid" do
      assert %Ecto.Changeset{} = changeset = Drops.change_drop(%Drop{}, @invalid_attrs)

      assert %{
               body: ["can't be blank"],
               title: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  describe "subscribe/0" do
    test "returns :ok and subscribes caller to the drops topic" do
      assert :ok == Drops.subscribe()
    end
  end
end
