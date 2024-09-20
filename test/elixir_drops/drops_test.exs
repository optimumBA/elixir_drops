defmodule ElixirDrops.DropsTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.Tag

  @invalid_attrs %{body: nil, tags: nil, title: nil}
  @valid_attrs %{body: "some body", drop_tags: "tag3, tag4", title: "some title"}

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
          %{title: "Drop 2", body: "Body for drop 2", drop_tags: "drop2, tag"}
        )

      assert [tagged_drop] = Drops.list_drops(%{tag: "tag1"})

      assert tagged_drop.id == drop.id
      assert Ecto.assoc_loaded?(tagged_drop.user)
      assert Ecto.assoc_loaded?(tagged_drop.tags)
    end

    test "returns an empty list if no drops match the given tag" do
      create_drops_setup(%{})

      drops_with_tag = Drops.list_drops(%{tag: "non-existent-tag"})

      assert Enum.empty?(drops_with_tag)
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

      drop_fixture(%Drop{}, user_2, %{title: "Drop 2", body: "Body for drop 2"})

      assert [user_drop] = Drops.list_drops(%{user_id: user.id})

      assert drop.id == user_drop.id
      assert Ecto.assoc_loaded?(user_drop.user)
      assert Ecto.assoc_loaded?(user_drop.tags)
    end

    test "returns empty list when a user has no drops" do
      non_existing_user_id = Ecto.UUID.generate()

      assert %{user_id: non_existing_user_id}
             |> Drops.list_drops()
             |> Enum.empty?()
    end

    test "can filter drops older than a given drop sorted by inserted_at" do
      user = user_fixture()

      [drop_1, drop_2, drop_3, _drop_4] =
        create_multiple_drops(user, 4)

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
        create_multiple_drops(user, 2)

      assert %{older_than: drop_1}
             |> Drops.list_drops()
             |> Enum.empty?()
    end

    test "can filter drops newer than a given drop sorted by inserted_at" do
      user = user_fixture()

      [_drop_1, drop_2, drop_3, drop_4] =
        create_multiple_drops(user, 4)

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
        create_multiple_drops(user, 2)

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
        create_multiple_drops(user, 3)

      create_multiple_drops(user_2, 3)

      assert [older_user_drop] =
               Drops.list_drops(%{user_id: user.id, older_than: drop_3, tag: "tag1"})

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

      create_multiple_drops(user, 1)

      [_drop_2, drop_3] = create_multiple_drops(user_2, 2)

      assert %{user_id: user_2.id, newer_than: drop_3}
             |> Drops.list_drops()
             |> Enum.empty?()
    end

    test "defaults to listing all drops if a non-existent filter is passed" do
      %{drop: drop} = create_drops_setup(%{})

      assert [result_drop] = Drops.list_drops(%{unknown_filter: "unknown_filter"})
      assert drop.id == result_drop.id
    end

    test "returns a list of all drops when no filter is passed" do
      create_drops_setup(%{})

      assert [drop] = Drops.list_drops()

      assert Ecto.assoc_loaded?(drop.user)
      assert Ecto.assoc_loaded?(drop.tags)
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

    test "returns an error changeset for a drop with less than 2 tags" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Drops.create_drop(%Drop{}, user, %{body: "body", title: "title", drop_tags: "tag1"})

      assert %{
               drop_tags: ["Should have at least 2 drops and at most 10 tags"]
             } = errors_on(changeset)
    end

    test "returns an error changeset for a drop with more than 10 tags" do
      user = user_fixture()
      tags = Enum.map_join(1..12, ", ", &"tag#{&1}")

      assert {:error, %Ecto.Changeset{} = changeset} =
               Drops.create_drop(%Drop{}, user, %{body: "body", drop_tags: tags, title: "title"})

      assert %{
               drop_tags: ["Should have at least 2 drops and at most 10 tags"]
             } = errors_on(changeset)
    end

    test "duplicate tags are not persistent" do
      user = user_fixture()

      Drops.create_drop(%Drop{}, user, %{
        body: "drop body",
        drop_tags: "tag1, tag1, TAG1",
        title: "Drop title"
      })

      assert tags = Repo.all(Tag)
      assert length(tags) == 1
      assert [%Tag{name: "tag1"}] = tags
    end
  end

  describe "update_drop/3" do
    setup [:create_drops_setup]

    test "updates an existing drop", %{drop: drop, user: user} do
      assert {:ok, %Drop{} = drop} =
               Drops.update_drop(drop, user, %{
                 body: "Updated body",
                 drop_tags: "tag6, tag7",
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
               Drops.update_drop(drop, user, %{body: "body", drop_tags: "tag1", title: "title"})

      assert %{
               drop_tags: ["Should have at least 2 drops and at most 10 tags"]
             } = errors_on(changeset)
    end

    test "returns an error changeset if the updated drop has more than 10 tags", %{
      drop: drop,
      user: user
    } do
      tags = Enum.map_join(1..12, ", ", &"tag#{&1}")

      assert {:error, %Ecto.Changeset{} = changeset} =
               Drops.update_drop(drop, user, %{body: "body", drop_tags: tags, title: "title"})

      assert %{
               drop_tags: ["Should have at least 2 drops and at most 10 tags"]
             } = errors_on(changeset)
    end
  end

  describe "get_drop/1" do
    setup [:create_drops_setup]

    test "returns the drop with given a drop_id", %{drop: drop} do
      assert %Drop{} = drop = Drops.get_drop(%{drop_id: drop.id})
      assert Ecto.assoc_loaded?(drop.tags)
      assert Ecto.assoc_loaded?(drop.user)
    end

    test "returns a drop belonging to a user", %{drop: drop, user: user} do
      assert %Drop{} = Drops.get_drop(%{drop_id: drop.id, user_id: user.id})

      assert Ecto.assoc_loaded?(drop.tags)
      assert Ecto.assoc_loaded?(drop.user)
    end

    test "returns nil for multiple filters whose conditions are not met", %{drop: drop} do
      user_2 =
        user_fixture(%{
          avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
          email: "user2@mail.com",
          github_id: 00_908,
          github_username: "github_username",
          name: "some_name"
        })

      refute Drops.get_drop(%{drop_id: drop.id, user_id: user_2.id})
    end

    test "returns nil if the drop does not exist" do
      non_existent_id = Ecto.UUID.generate()

      refute Drops.get_drop(%{drop_id: non_existent_id})
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
               drop_tags: ["can't be blank"],
               title: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  describe "get_tag_by_name/1" do
    setup [:create_drops_setup]

    test "filters drops by tag names" do
      assert [tag1, tag2] = Drops.get_tag_by_name("tag")

      assert tag1.name == "tag1"
      assert tag2.name == "tag2"
    end

    test "returns and empty list if no tag matches the given name" do
      assert "non-existent"
             |> Drops.get_tag_by_name()
             |> Enum.empty?()
    end
  end

  describe "subscribe/0" do
    test "returns :ok and subscribes caller to the drops topic" do
      assert :ok == Drops.subscribe()
    end
  end
end
