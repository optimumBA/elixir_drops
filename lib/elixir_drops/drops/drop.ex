defmodule ElixirDrops.Drops.Drop do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, warn: false

  alias ElixirDrops.Accounts.User

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "drops" do
    field :title, :string
    field :body, :string
    field :unique_url_string, :string

    belongs_to :user, User

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = drop, attrs \\ %{}) do
    drop
    |> cast(attrs, [:body, :title, :unique_url_string, :user_id])
    |> validate_required([:body, :title, :unique_url_string])
    |> unique_constraint(:unique_url_string)
  end
end
