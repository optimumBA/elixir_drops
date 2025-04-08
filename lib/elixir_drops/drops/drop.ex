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
    field :body, :string
    field :screenshot_status, :string
    field :screenshot_url, :string
    field :short_id, :string
    field :title, :string

    belongs_to :user, User

    timestamps()
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = drop, attrs \\ %{}) do
    drop
    |> cast(attrs, [:body, :short_id, :title, :user_id, :screenshot_status, :screenshot_url])
    |> validate_required([:body, :short_id, :title])
    |> unique_constraint(:short_id)
  end
end
