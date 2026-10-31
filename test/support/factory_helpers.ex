defmodule ElixirDrops.FactoryHelpers do
  @moduledoc """
  Helper functions to assist in pagination tests.
  """

  alias ElixirDrops.Repo

  @type record :: map()

  @spec update_inserted_at(record(), non_neg_integer()) :: record()
  def update_inserted_at(struct, seconds_offset) do
    {:ok, updated_struct} =
      struct
      |> Ecto.Changeset.change(%{inserted_at: time_before_or_after(seconds_offset)})
      |> Repo.update()

    updated_struct
  end

  defp time_before_or_after(seconds_offset) do
    DateTime.utc_now()
    |> DateTime.add(seconds_offset)
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
  end
end
