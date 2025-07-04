defmodule ElixirDrops.Drops.Drop do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User
  alias ElixirDrops.Drops.Screenshot

  @type attrs :: map()
  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "drops" do
    field :body, :string
    embeds_one :screenshot, Screenshot, on_replace: :update
    field :short_id, :string
    field :title, :string
    field :comment_count, :integer, virtual: true

    belongs_to :user, User

    timestamps()
  end

  @spec changeset(t(), attrs()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = drop, attrs \\ %{}) do
    drop
    |> cast(attrs, [:body, :short_id, :title, :user_id])
    |> cast_embed(:screenshot)
    |> validate_required([:body, :short_id, :title])
    |> unique_constraint(:short_id)
  end
end
