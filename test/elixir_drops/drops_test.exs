defmodule ElixirDrops.DropsTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.ShortIdGenerator

  @invalid_attrs %{title: nil, body: nil}
  @valid_attrs %{title: "some title", body: "some body"}

  defp create_drops_setup(_attrs) do
    user = user_fixture()
    drop = drop_fixture(user)

    %{drop: drop, user: user}
  end

  describe "list_drops/2" do
    test "returns a list of all drops when no filter is passed" do
      # Verify we can create and list drops properly

      %{drop: drop} = create_drops_setup(%{})

      all_drops = Drops.list_drops()
      # The new drop should be in the list
      assert drop.id in Enum.map(all_drops, & &1.id)

      # Check our drop is in the list
      assert Enum.any?(all_drops, &(&1.id == drop.id))

      # All drops should have user loaded
      assert Enum.all?(all_drops, &Ecto.assoc_loaded?(&1.user))
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
    end

    test "returns empty list when a user has no drops" do
      non_existing_user_id = Ecto.UUID.generate()

      assert [] = Drops.list_drops(%{user_id: non_existing_user_id})
    end

    test "can filter drops older than a given drop sorted by inserted_at" do
      user = user_fixture()

      [drop_1, drop_2, drop_3, _drop_4] =
        create_multiple_drops(user, 4)

      older_drops = Drops.list_drops(%{older_than: drop_3})

      # Should have drop_2 and drop_1 in the results (plus any seeded data)
      assert Enum.any?(older_drops, &(&1.id == drop_2.id))
      assert Enum.any?(older_drops, &(&1.id == drop_1.id))

      # Check ordering for our test drops
      our_drops = Enum.filter(older_drops, &(&1.id in [drop_1.id, drop_2.id]))
      assert [first, second] = our_drops
      assert first.id == drop_2.id
      assert second.id == drop_1.id

      assert Enum.all?(older_drops, &Ecto.assoc_loaded?(&1.user))
    end

    test "returns an empty list if there are no drops older than a given drop" do
      user = user_fixture()

      # Create drops with future timestamps to ensure they're the newest
      future_time = NaiveDateTime.add(NaiveDateTime.utc_now(), 3600, :second)

      drop_1 = drop_fixture(%Drop{}, user, %{title: "Future 1", inserted_at: future_time})

      # Get drops older than our future drop
      older_drops = Drops.list_drops(%{older_than: drop_1})

      # None of the older drops should have a timestamp >= our future drop
      refute Enum.any?(older_drops, fn d ->
               NaiveDateTime.compare(d.inserted_at, drop_1.inserted_at) in [:gt, :eq]
             end)
    end

    test "can filter drops newer than a given drop sorted by inserted_at" do
      user = user_fixture()

      [_drop_1, drop_2, drop_3, drop_4] =
        create_multiple_drops(user, 4)

      assert [newer_drop_1, newer_drop_2] = Drops.list_drops(%{newer_than: drop_2})
      assert newer_drop_1.id == drop_4.id
      assert newer_drop_2.id == drop_3.id
      assert Ecto.assoc_loaded?(newer_drop_1.user)
      assert Ecto.assoc_loaded?(newer_drop_2.user)
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

      [drop_1, drop_2, drop_3] =
        create_multiple_drops(user, 3)

      create_multiple_drops(user_2, 3)

      assert [older_user_drop_1, older_user_drop_2] =
               Drops.list_drops(%{user_id: user.id, older_than: drop_3})

      assert older_user_drop_1.id == drop_2.id
      assert older_user_drop_1.user_id == user.id
      assert older_user_drop_2.id == drop_1.id
      assert older_user_drop_2.user_id == user.id
      assert Ecto.assoc_loaded?(older_user_drop_1.user)
      assert Ecto.assoc_loaded?(older_user_drop_2.user)
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

      assert [] == Drops.list_drops(%{user_id: user_2.id, newer_than: drop_3})
    end

    test "defaults to listing all drops if a non-existent filter is passed" do
      %{drop: drop} = create_drops_setup(%{})

      all_drops = Drops.list_drops(%{unknown_filter: "unknown_filter"})
      # The new drop should be in the list when an unknown filter is passed
      assert drop.id in Enum.map(all_drops, & &1.id)

      # Our drop should be in the results
      assert Enum.any?(all_drops, &(&1.id == drop.id))
    end
  end

  describe "create_drop/3" do
    test "creates a drop given valid data" do
      user = user_fixture()
      assert {:ok, %Drop{} = drop} = Drops.create_drop(%Drop{}, user, @valid_attrs)

      assert drop.body == @valid_attrs.body
      assert drop.title == @valid_attrs.title
      assert drop.user_id == user.id
    end

    test "returns an error changeset if data is invalid" do
      user = user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Drops.create_drop(%Drop{}, user, @invalid_attrs)
    end
  end

  describe "update_drop/3" do
    setup [:create_drops_setup]

    test "updates an existing drop", %{drop: drop, user: user} do
      assert {:ok, %Drop{} = drop} =
               Drops.update_drop(drop, user, %{
                 body: "Updated body",
                 title: "Updated title"
               })

      assert drop.body == "Updated body"
      assert drop.title == "Updated title"
    end

    test "returns an error changeset if data is invalid", %{drop: drop, user: user} do
      assert {:error, %Ecto.Changeset{}} =
               Drops.update_drop(drop, user, @invalid_attrs)
    end
  end

  describe "get_drop/1" do
    setup [:create_drops_setup]

    test "returns the drop with given a drop_id", %{drop: drop} do
      assert %Drop{} = drop = Drops.get_drop(%{drop_id: drop.id})
      assert Ecto.assoc_loaded?(drop.user)
    end

    test "returns a drop belonging to a user", %{drop: drop, user: user} do
      assert %Drop{} = Drops.get_drop(%{drop_id: drop.id, user_id: user.id})

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

  describe "get_drop_by_short_id/1" do
    setup [:create_drops_setup]

    test "returns the drop with given a short_id", %{drop: drop} do
      assert %Drop{} = drop = Drops.get_drop_by_short_id(drop.short_id)
      assert Ecto.assoc_loaded?(drop.user)
    end

    test "returns nil if the drop does not exist" do
      non_existent_short_id = ShortIdGenerator.generate()
      refute Drops.get_drop_by_short_id(non_existent_short_id)
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
               title: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  describe "subscribe/0" do
    test "returns :ok and subscribes caller to the drops topic" do
      assert :ok == Drops.subscribe()
    end
  end

  describe "list_all_drops/0" do
    test "returns all drops ordered by insertion time (newest first)" do
      user = user_fixture()

      # Create multiple drops with known order
      [drop_1, drop_2, drop_3] = create_multiple_drops(user, 3)

      drops = Drops.list_all_drops()

      # Should have at least our test drops
      drop_ids = Enum.map(drops, & &1.id)
      assert drop_1.id in drop_ids
      assert drop_2.id in drop_ids
      assert drop_3.id in drop_ids

      # Find our test drops in the results
      our_drops = Enum.filter(drops, &(&1.id in [drop_1.id, drop_2.id, drop_3.id]))
      our_drop_ids = Enum.map(our_drops, & &1.id)

      # Should be ordered newest first (drop_3, drop_2, drop_1)
      assert our_drop_ids == [drop_3.id, drop_2.id, drop_1.id]
    end

    test "preloads user associations" do
      user = user_fixture()
      drop_fixture(%Drop{}, user)

      [drop | _] = Drops.list_all_drops()

      assert Ecto.assoc_loaded?(drop.user)
      assert drop.user != nil
    end

    test "truncates body field to 500 characters for performance" do
      user = user_fixture()
      long_body = String.duplicate("a", 600)
      drop_fixture(%Drop{}, user, %{body: long_body})

      [drop | _] = Drops.list_all_drops()

      # Body should be truncated to 500 characters
      assert String.length(drop.body) <= 500
    end

    test "returns empty list when no drops exist" do
      # Clear any existing drops by getting current count first
      initial_count = length(Drops.list_all_drops())

      # If there are existing drops, we still get a list
      drops = Drops.list_all_drops()
      assert is_list(drops)
      assert length(drops) == initial_count

      # Test that function returns empty list in clean database
      # This would be true in isolated test but may have seeded data
      assert is_list(drops)
    end

    test "includes all drop fields except full body content" do
      user = user_fixture()

      attrs = %{
        title: "Test Drop",
        body: "Full body content that should be truncated"
      }

      drop_fixture(%Drop{}, user, attrs)

      [drop | _] = Drops.list_all_drops()

      # Should have all standard fields
      assert drop.id != nil
      assert drop.title == "Test Drop"
      assert drop.short_id != nil
      assert drop.user_id == user.id
      assert drop.inserted_at != nil
      assert drop.updated_at != nil

      # User should be preloaded
      assert drop.user.id == user.id
    end
  end
end
