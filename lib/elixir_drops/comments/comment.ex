defmodule ElixirDrops.Comments.Comment do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments.Comment
  alias ElixirDrops.Drops.Drop

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "comments" do
    field :body, :string
    field :edited_at, :utc_datetime_usec

    belongs_to :drop, Drop
    belongs_to :parent, Comment
    belongs_to :user, User

    has_many :replies, Comment, foreign_key: :parent_id

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :edited_at])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 1000)
  end
end
