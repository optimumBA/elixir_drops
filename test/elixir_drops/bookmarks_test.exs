defmodule ElixirDrops.BookmarksTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
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
    setup [:create_user_and_drop]

    test "with valid data creates a bookmark for a drop and user", %{
      attrs: attrs,
      drop: drop,
      user: user
    } do
      assert {:ok, %Bookmark{} = bookmark} =
               Bookmarks.create_bookmark(attrs)

      assert bookmark.drop_id == drop.id
      assert bookmark.user_id == user.id
    end

    test "returns an error changeset when bookmarking the same drop twice", %{
      attrs: attrs
    } do
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
      assert {:ok, %Bookmark{} = created} = Bookmarks.create_bookmark(attrs)

      assert %Bookmark{} = fetched = Bookmarks.get_bookmark(drop.id, user.id)
      assert fetched.id == created.id
      assert fetched.drop_id == drop.id
      assert fetched.user_id == user.id
    end

    test "returns nil when no bookmark exists for the pair", %{user: user, drop: drop} do
      refute Bookmarks.get_bookmark(drop.id, user.id)
    end
  end

  describe "get_bookmarked_drops/1" do
    test "returns empty list when user has no bookmarks" do
      user = user_fixture()
      filters = %{user_id: user.id}

      assert [] ==
               filters
               |> Bookmarks.get_bookmarks()
               |> Bookmarks.get_bookmarked_drops()
    end

    test "returns drops bookmarked by the user" do
      user = user_fixture()
      filters = %{user_id: user.id}
      drops = create_multiple_drops(user, 2)

      Enum.each(drops, fn drop ->
        attrs = %{drop_id: drop.id, user_id: user.id}
        assert {:ok, _} = Bookmarks.create_bookmark(attrs)
      end)

      bookmarked_drops =
        filters
        |> Bookmarks.get_bookmarks()
        |> Bookmarks.get_bookmarked_drops()

      assert length(bookmarked_drops) == 2

      drop_ids = Enum.map(bookmarked_drops, & &1.id)
      Enum.each(drops, fn d -> assert d.id in drop_ids end)

      assert Enum.all?(bookmarked_drops, &Ecto.assoc_loaded?(&1.user))
    end
  end

  describe "delete_bookmark/1" do
    setup [:create_user_and_drop]

    test "deletes an existing bookmark", %{
      attrs: attrs,
      drop: drop,
      user: user
    } do
      assert {:ok, %Bookmark{} = bookmark} = Bookmarks.create_bookmark(attrs)
      assert {:ok, %Bookmark{}} = Bookmarks.delete_bookmark(bookmark)
      refute Bookmarks.get_bookmark(drop.id, user.id)
    end
  end
end
