defmodule ElixirDrops.Bookmarks.Bookmark do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops.Drop

  @type attrs :: map()
  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bookmarks" do
    belongs_to :drop, Drop
    belongs_to :user, User

    timestamps()
  end

  @spec changeset(t(), attrs()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = bookmark, attrs \\ %{}) do
    bookmark
    |> cast(attrs, [:drop_id, :user_id])
    |> validate_required([:drop_id, :user_id])
    |> unique_constraint([:user_id, :drop_id],
      name: :bookmarks_user_id_drop_id_index,
      message: "already bookmarked"
    )
  end
end
