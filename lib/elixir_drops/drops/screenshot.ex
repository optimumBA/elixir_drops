defmodule ElixirDrops.Drops.Screenshot do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}
  @type attrs :: map()

  @primary_key false
  embedded_schema do
    field :meta, :map,
      default: %{
        status: :skipped,
        url: nil
      }

    field :internal, :map,
      default: %{
        status: :skipped,
        url: nil
      }
  end

  @spec changeset(t(), attrs()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = screenshot, attrs \\ %{}) do
    screenshot
    |> cast(attrs, [:meta, :internal])
    |> validate_required([:meta, :internal])
  end
end
