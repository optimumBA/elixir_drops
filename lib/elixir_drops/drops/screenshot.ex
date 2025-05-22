defmodule ElixirDrops.Drops.Screenshot do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}
  @type attrs :: map()

  @primary_key false
  embedded_schema do
    field :internal_url, :string
    field :meta_url, :string
    field :status, Ecto.Enum, values: [:pending, :completed, :failed, :skipped], default: :skipped
  end

  @spec changeset(t(), attrs()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = screenshot, attrs \\ %{}) do
    screenshot
    |> cast(attrs, [:internal_url, :meta_url, :status])
    |> validate_required([:status])
  end
end
