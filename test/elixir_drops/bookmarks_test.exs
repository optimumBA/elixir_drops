defmodule ElixirDrops.BookmarksTest do
  use ElixirDrops.DataCase, async: true

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures

  alias ElixirDrops.Bookmarks
  alias ElixirDrops.Bookmarks.Bookmark
  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDrops.Repo

  setup do
    user = user_fixture()
    other = user_fixture()
    drop = drop_fixture(%Drop{}, other, %{title: "Bookmarked drop"})
    %{drop: drop, other: other, user: user}
  end

  describe "save_bookmark/2 and remove_bookmark/2" do
    test "saving is idempotent and keeps the original save time", %{drop: drop, user: user} do
      assert :ok = Bookmarks.save_bookmark(user.id, drop.id)
      [first] = Repo.all(Bookmark)

      assert :ok = Bookmarks.save_bookmark(user.id, drop.id)

      assert [%Bookmark{id: id, inserted_at: at}] = Repo.all(Bookmark)
      assert id == first.id
      assert at == first.inserted_at
      assert Bookmarks.bookmarked?(user.id, drop.id)
    end

    test "removing an unsaved Drop changes nothing", %{drop: drop, user: user} do
      assert :ok = Bookmarks.remove_bookmark(user.id, drop.id)
      assert :ok = Bookmarks.remove_bookmark(user.id, "not-a-uuid")
      refute Bookmarks.bookmarked?(user.id, drop.id)
    end

    test "removing only drops the account's own bookmark", %{drop: drop, other: other, user: user} do
      :ok = Bookmarks.save_bookmark(user.id, drop.id)
      :ok = Bookmarks.save_bookmark(other.id, drop.id)

      assert :ok = Bookmarks.remove_bookmark(user.id, drop.id)

      refute Bookmarks.bookmarked?(user.id, drop.id)
      assert Bookmarks.bookmarked?(other.id, drop.id)
      assert Bookmarks.count_drop_bookmarks(drop.id) == 1
    end

    test "an unknown Drop is not found", %{user: user} do
      assert {:error, :not_found} = Bookmarks.save_bookmark(user.id, Ecto.UUID.generate())
      assert {:error, :not_found} = Bookmarks.save_bookmark(user.id, "not-a-uuid")
    end

    test "deleting the Drop or the account removes its bookmarks", %{
      drop: drop,
      other: other,
      user: user
    } do
      kept = drop_fixture(%Drop{}, other, %{title: "Kept drop"})
      :ok = Bookmarks.save_bookmark(user.id, drop.id)
      :ok = Bookmarks.save_bookmark(user.id, kept.id)

      Repo.delete!(drop)
      assert Repo.aggregate(Bookmark, :count) == 1

      Repo.delete!(user)
      assert Repo.aggregate(Bookmark, :count) == 0
    end
  end

  describe "maybe_mark_bookmarked/2" do
    @describetag error_path_exemption:
                   "nothing to reject: a visitor and unsaved Drops are simply unmarked"

    test "marks the saved Drops of the account only", %{drop: drop, other: other, user: user} do
      second = drop_fixture(%Drop{}, other, %{title: "Second drop"})
      :ok = Bookmarks.save_bookmark(user.id, drop.id)
      :ok = Bookmarks.save_bookmark(other.id, second.id)

      marked = Bookmarks.maybe_mark_bookmarked([drop, second], user.id)

      assert Enum.map(marked, & &1.bookmarked) == [true, false]
    end

    test "a visitor has saved nothing and costs no query", %{drop: drop} do
      assert [%Drop{bookmarked: false}] = Bookmarks.maybe_mark_bookmarked([drop], nil)
      assert is_nil(Bookmarks.mark_bookmarked_drop(nil, nil))
    end
  end

  describe "list_bookmarked_drops/3" do
    test "lists the account's Drops latest saved first, batch by batch", %{
      other: other,
      user: user
    } do
      drops = for i <- 1..5, do: drop_fixture(%Drop{}, other, %{title: "Listed #{i}"})
      for drop <- drops, do: :ok = Bookmarks.save_bookmark(user.id, drop.id)
      # A re-saved Drop returns to the top.
      first = hd(drops)
      :ok = Bookmarks.remove_bookmark(user.id, first.id)
      :ok = Bookmarks.save_bookmark(user.id, first.id)
      _someone_elses = Bookmarks.save_bookmark(other.id, List.last(drops).id)

      expected = ["Listed 1", "Listed 5", "Listed 4", "Listed 3", "Listed 2"]

      batch1 = Drops.list_bookmarked_drops(user.id, 2)
      batch2 = Drops.list_bookmarked_drops(user.id, 2, List.last(batch1))
      batch3 = Drops.list_bookmarked_drops(user.id, 2, List.last(batch2))

      assert Enum.map(batch1 ++ batch2 ++ batch3, & &1.title) == expected
      assert Enum.all?(batch1, &(&1.bookmarked and &1.user.id == other.id))
      assert Drops.list_bookmarked_drops(user.id, 2, List.last(batch3)) == []
      others = Drops.list_bookmarked_drops(other.id, 10)
      assert Enum.map(others, & &1.title) == ["Listed 5"]
    end
  end
end
