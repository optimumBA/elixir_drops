defmodule ElixirDrops.Drops.Screenshot do
  @moduledoc """
  Embedded schema for managing screenshot data related to drops.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :status, :string
    field :url, :string
  end

  @doc """
  Changeset function for the Screenshot schema.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = screenshot, attrs \\ %{}) do
    screenshot
    |> cast(attrs, [:status, :url])
    |> validate_required([:status])
  end
end
