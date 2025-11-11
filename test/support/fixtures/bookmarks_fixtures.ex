# defmodule ElixirDrops.BookmarksFixtures do
#   import ElixirDrops.DropsFixtures

#   @doc """
#   Create a bookmark.
#   """
#   @spec bookmark_fixture(drop(), user(), map()) :: drop()
#   def bookmark_fixture(drop \\ %Drop{}, %User{} = user, attrs \\ %{}) do
#     drop_attrs =
#       Enum.into(attrs, %{
#         body: "Drop body text ```code block```...",
#         screenshot: %{
#           internal_url: nil,
#           meta_url: nil,
#           status: :completed
#         },
#         title: drop_title
#       })

#     {:ok, drop} =
#       Drops.create_drop(drop, user, drop_attrs)

#     {:ok, bookmark} =
#       Bookmarks.create_bookmark(drop.id, user.id)

#     bookmark
#   end
# end
