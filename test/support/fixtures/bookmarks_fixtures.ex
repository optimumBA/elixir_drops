defmodule ElixirDrops.BookmarksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirDrops.Bookmarks` context.
  """

  import ElixirDrops.AccountsFixtures
  import ElixirDrops.DropsFixtures
  import ElixirDrops.FactoryHelpers

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Bookmarks
  alias ElixirDrops.Bookmarks.Bookmark
  alias ElixirDrops.Drops.Drop

  @type attrs :: map()
  @type body :: String.t()
  @type bookmark :: Bookmark.t()
  @type drop :: Drop.t()
  @type title :: String.t()
  @type user :: User.t()

  @doc """
  Create a bookmark.
  """
  @spec bookmark_fixture(attrs()) :: bookmark()
  def bookmark_fixture(attrs \\ %{}) do
    user = user_fixture()
    drop = drop_fixture(user)

    bookmark_attrs =
      Enum.into(attrs, %{
        drop_id: drop.id,
        user_id: user.id
      })

    {:ok, bookmark} = Bookmarks.create_bookmark(bookmark_attrs)
    bookmark
  end

  @spec create_multiple_bookmarks(user(), integer()) :: [bookmark()]
  def create_multiple_bookmarks(user, num_of_bookmarks \\ 10) do
    bookmarks =
      user
      |> create_multiple_drops(num_of_bookmarks)
      |> Enum.map(&bookmark_fixture(%{drop_id: &1.id, user_id: user.id}))

    for bookmark_num <- 1..num_of_bookmarks do
      offset_time = 120 * bookmark_num

      bookmarks
      |> Enum.at(bookmark_num - 1)
      |> update_inserted_at(offset_time)
    end
  end

  @spec create_bookmark(user(), title(), body()) :: drop()
  def create_bookmark(user, title, body) do
    %Drop{}
    |> drop_fixture(user, %{
      title: title,
      body: body
    })
    |> tap(&bookmark_fixture(%{drop_id: &1.id, user_id: user.id}))
  end
end
