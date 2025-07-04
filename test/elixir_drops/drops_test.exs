defmodule ElixirDrops.DropsTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Drops.ShortIdGenerator
  alias ElixirDrops.Repo

  @invalid_attrs %{title: nil, body: nil}
  @valid_attrs %{title: "some title", body: "some body"}

  defp create_drops_setup(_attrs) do
    user = user_fixture()
    drop = drop_fixture(user)

    %{drop: drop, user: user}
  end

  # Helper to update search vectors in test environment since triggers don't fire properly
  defp update_search_vectors do
    Repo.query!(
      "UPDATE drops SET search_vector = setweight(to_tsvector('english', coalesce(title, '')), 'A') || setweight(to_tsvector('english', coalesce(body, '')), 'B')"
    )
  end

  describe "list_drops/2" do
    test "returns a list of all drops when no filter is passed" do
      create_drops_setup(%{})

      assert [drop] = Drops.list_drops()

      assert Ecto.assoc_loaded?(drop.user)
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

      assert [older_drop_1, older_drop_2] = Drops.list_drops(%{older_than: drop_3})
      assert older_drop_1.id == drop_2.id
      assert older_drop_2.id == drop_1.id
      assert Ecto.assoc_loaded?(older_drop_1.user)
      assert Ecto.assoc_loaded?(older_drop_2.user)
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

  describe "search functionality" do
    test "searches drops by title" do
      user = user_fixture()

      drop1 =
        drop_fixture(%Drop{}, user, %{title: "Phoenix LiveView Tutorial", body: "Some content"})

      _drop2 =
        drop_fixture(%Drop{}, user, %{title: "Elixir GenServer Guide", body: "Other content"})

      update_search_vectors()

      results = Drops.list_drops(%{search: "Phoenix"})
      assert length(results) == 1
      assert hd(results).id == drop1.id
      assert Ecto.assoc_loaded?(hd(results).user)
    end

    test "searches drops by body content" do
      user = user_fixture()

      _drop1 =
        drop_fixture(%Drop{}, user, %{
          title: "Tutorial 1",
          body: "defmodule MyApp.PageLive do\n  use Phoenix.LiveView\nend"
        })

      _drop2 =
        drop_fixture(%Drop{}, user, %{
          title: "Tutorial 2",
          body: "defmodule MyApp.Worker do\n  use GenServer\nend"
        })

      update_search_vectors()

      # Test search by title
      title_filters = %{search: "Tutorial", screenshot_status: [:completed, :skipped]}
      title_results = Drops.list_drops(title_filters)
      assert length(title_results) == 2

      # Test search by body content using a term that definitely exists
      body_filters = %{search: "defmodule", screenshot_status: [:completed, :skipped]}
      body_results = Drops.list_drops(body_filters)
      assert length(body_results) == 2
      assert Ecto.assoc_loaded?(hd(body_results).user)
    end

    test "searches drops by both title and body" do
      user = user_fixture()
      drop1 = drop_fixture(%Drop{}, user, %{title: "Phoenix Tutorial", body: "LiveView content"})
      drop2 = drop_fixture(%Drop{}, user, %{title: "LiveView Guide", body: "Elixir content"})
      _drop3 = drop_fixture(%Drop{}, user, %{title: "GenServer Guide", body: "GenServer content"})

      update_search_vectors()

      results = Drops.list_drops(%{search: "LiveView"})
      result_ids = Enum.map(results, & &1.id)
      assert length(results) == 2
      assert drop1.id in result_ids
      assert drop2.id in result_ids
    end

    test "handles quoted phrases in search" do
      user = user_fixture()
      drop1 = drop_fixture(%Drop{}, user, %{title: "Phoenix LiveView Tutorial", body: "Content"})
      _drop2 = drop_fixture(%Drop{}, user, %{title: "Phoenix Framework Guide", body: "Content"})

      update_search_vectors()

      results = Drops.list_drops(%{search: "\"Phoenix LiveView\""})
      assert length(results) == 1
      assert hd(results).id == drop1.id
    end

    test "returns empty list for no matches" do
      user = user_fixture()
      _drop = drop_fixture(%Drop{}, user, %{title: "Elixir Tutorial", body: "Elixir content"})

      update_search_vectors()

      results = Drops.list_drops(%{search: "Python"})
      assert results == []
    end

    test "orders results by relevance (title matches ranked higher)" do
      user = user_fixture()
      _drop1 = drop_fixture(%Drop{}, user, %{title: "Phoenix Guide", body: "Some content"})

      drop2 =
        drop_fixture(%Drop{}, user, %{
          title: "Phoenix LiveView Tutorial",
          body: "Phoenix is great for LiveView apps"
        })

      update_search_vectors()

      results = Drops.list_drops(%{search: "Phoenix"})
      assert length(results) == 2
      # drop2 should rank higher due to more matches and title weight
      assert hd(results).id == drop2.id
    end

    test "search is case insensitive" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user, %{title: "Phoenix LiveView", body: "Content"})

      update_search_vectors()

      results = Drops.list_drops(%{search: "phoenix liveview"})
      assert length(results) == 1
      assert hd(results).id == drop.id
    end

    test "ignores empty search terms" do
      user = user_fixture()
      drop = drop_fixture(%Drop{}, user, %{title: "Test", body: "Content"})

      # Empty string should not filter (returns all drops)
      results = Drops.list_drops(%{search: ""})
      assert length(results) == 1
      assert hd(results).id == drop.id

      # No search filter should return all drops
      no_search_results = Drops.list_drops(%{})
      assert length(no_search_results) == 1
      assert hd(no_search_results).id == drop.id
    end

    test "can combine search with other filters" do
      user1 = user_fixture()

      user2 =
        user_fixture(%{
          avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
          email: "user2@mail.com",
          github_id: 12_345,
          github_username: "github_username2",
          name: "some_name2"
        })

      drop1 = drop_fixture(%Drop{}, user1, %{title: "Phoenix Tutorial", body: "Content"})
      _drop2 = drop_fixture(%Drop{}, user1, %{title: "Elixir Guide", body: "Content"})
      _drop3 = drop_fixture(%Drop{}, user2, %{title: "Phoenix Guide", body: "Content"})

      update_search_vectors()

      results = Drops.list_drops(%{search: "Phoenix", user_id: user1.id})
      assert length(results) == 1
      assert hd(results).id == drop1.id
    end
  end
end
