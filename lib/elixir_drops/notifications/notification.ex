defmodule ElixirDrops.Notifications.Notification do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Comments.Comment

  @type attrs :: map()
  @type changeset :: Ecto.Changeset.t()
  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notifications" do
    belongs_to :actor, User
    belongs_to :comment, Comment
    field :read, :boolean, default: false
    belongs_to :recipient, User
    field :type, Ecto.Enum, values: [:comment_on_post, :reply_to_comment]

    timestamps()
  end

  @spec changeset(t(), attrs()) :: changeset()
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:read, :type])
    |> validate_required([:read, :type])
  end
end
