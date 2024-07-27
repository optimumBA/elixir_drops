defmodule ElixirDrops.DateTimeHelper do
  @moduledoc """
  Helper functions for date/time formatting.
  """

  @doc """
  Adds timezone offset and converts a NaiveDateTime to a relative time string.

  ## Examples
      iex> ElixirDrops.DateTimeHelper.convert_to_relative_time(~N[2019-01-01 00:00:00], 3600)
      "1 hour ago"

  """
  @spec convert_to_relative_time(NaiveDateTime.t(), integer()) :: String.t()
  def convert_to_relative_time(time, timezone_offset) do
    {:ok, created_at_time} =
      time
      |> NaiveDateTime.add(timezone_offset, :second)
      |> Timex.format("{relative}", :relative)

    created_at_time
  end
end
