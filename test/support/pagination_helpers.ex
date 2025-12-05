defmodule ElixirDrops.PaginationHelpers do
  @moduledoc """
  Helper functions to assist in pagination tests.
  """

  alias ElixirDrops.Repo

  @spec update_inserted_at(map(), non_neg_integer()) :: map()
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
