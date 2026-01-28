defmodule ElixirDrops.BookmarksTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.BookmarksFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Bookmarks
  alias ElixirDrops.Bookmarks.Bookmark
  alias ElixirDrops.Drops.Drop

  defp create_user_and_drop(_attrs) do
    user = user_fixture()
    drop = drop_fixture(%Drop{}, user)
    attrs = %{drop_id: drop.id, user_id: user.id}

    %{attrs: attrs, drop: drop, user: user}
  end

  describe "create_bookmark/1" do
    test "with valid data creates a bookmark for a drop and user" do
      %{attrs: attrs, drop: drop, user: user} = create_user_and_drop(%{})

      assert {:ok, %Bookmark{} = bookmark} =
               Bookmarks.create_bookmark(attrs)

      assert bookmark.drop_id == drop.id
      assert bookmark.user_id == user.id
    end

    test "with invalid data returns an error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Bookmarks.create_bookmark(%{drop_id: nil, user_id: nil})
    end

    test "returns an error changeset when bookmarking the same drop twice" do
      %{attrs: attrs} = create_user_and_drop(%{})
      assert {:ok, %Bookmark{}} = Bookmarks.create_bookmark(attrs)
      assert {:error, changeset} = Bookmarks.create_bookmark(attrs)

      errors = errors_on(changeset)
      assert "already bookmarked" in errors[:user_id]
    end
  end

  describe "get_bookmark/2" do
    setup [:create_user_and_drop]

    test "returns the bookmark given drop_id and user_id", %{
      attrs: attrs,
      drop: drop,
      user: user
    } do
      created_bookmark = bookmark_fixture(attrs)
      assert %Bookmark{} = fetched_bookmark = Bookmarks.get_bookmark(drop.id, user.id)
      assert fetched_bookmark.id == created_bookmark.id
      assert fetched_bookmark.drop_id == drop.id
      assert fetched_bookmark.user_id == user.id
    end

    test "returns nil when no bookmark exists for the pair", %{user: user, drop: drop} do
      refute Bookmarks.get_bookmark(drop.id, user.id)
    end
  end

  describe "get_bookmarks/2" do
    test "if searching, orders bookmarks by the relevance rank" do
      user =
        user_fixture(%{
          avatar: "https://avatars.githubusercontent.com/u/1456872?v=4",
          email: "user2@mail.com",
          github_id: 12_345,
          github_username: "github_username",
          name: "some_name"
        })

      drop_1 =
        drop_fixture(%Drop{}, user, %{
          title: "Phoenix liveview for form submissions",
          body: "I was diving into liveview this week"
        })

      bookmark_fixture(%{drop_id: drop_1.id, user_id: user.id})

      drop_2 =
        drop_fixture(%Drop{}, user, %{
          title: "Phoenix LiveView for form submissions because LiveView is Good",
          body: "LiveView to manage state"
        })

      bookmark_fixture(%{drop_id: drop_2.id, user_id: user.id})

      bookmarks = Bookmarks.get_bookmarks(%{user_id: user.id, search: "LiveView"})

      first_bookmark = Enum.at(bookmarks, 0)
      second_bookmark = Enum.at(bookmarks, 1)

      assert first_bookmark.relevance_rank > second_bookmark.relevance_rank
    end
  end

  describe "get_bookmarked_drops/1" do
    test "returns drops bookmarked by the user" do
      user = user_fixture()
      bookmarks = create_multiple_bookmarks(user, 2)

      bookmarked_drops =
        %{user_id: user.id}
        |> Bookmarks.get_bookmarks()
        |> Bookmarks.get_bookmarked_drops()

      drop_ids = Enum.map(bookmarked_drops, & &1.id)

      assert length(bookmarked_drops) == 2
      Enum.each(bookmarks, fn bookmark -> assert bookmark.drop_id in drop_ids end)
      assert Enum.all?(bookmarked_drops, &Ecto.assoc_loaded?(&1.user))
    end

    test "returns empty list when user has no bookmarks" do
      user = user_fixture()

      assert [] ==
               %{user_id: user.id}
               |> Bookmarks.get_bookmarks()
               |> Bookmarks.get_bookmarked_drops()
    end
  end

  describe "delete_bookmark/1" do
    setup [:create_user_and_drop]

    test "deletes an existing bookmark", %{
      attrs: attrs,
      drop: drop,
      user: user
    } do
      bookmark = bookmark_fixture(attrs)
      assert {:ok, %Bookmark{}} = Bookmarks.delete_bookmark(bookmark)
      refute Bookmarks.get_bookmark(drop.id, user.id)
    end
  end
end
