defmodule ElixirDrops.Notifications.Notification do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments.Comment

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notifications" do
    field :read, :boolean, default: false
    field :type, Ecto.Enum, values: [:comment_on_post, :reply_to_comment]

    belongs_to :actor, User
    belongs_to :comment, Comment
    belongs_to :recipient, User

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:read, :type])
    |> validate_required([:read, :type])
  end
end
