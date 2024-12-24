defmodule ElixirDrops.DateTimeHelper do
  @moduledoc """
  Helper functions for date/time formatting.
  """

  @doc """
  Adds timezone offset to NaiveDateTime.

  ## Examples

      iex> ElixirDrops.DateTimeHelper.apply_timezone_offset(~N[2019-01-01 00:00:00], 3600)
      "5 years ago"

  """
  @spec apply_timezone_offset(NaiveDateTime.t(), integer()) :: NaiveDateTime.t()
  def apply_timezone_offset(time, timezone_offset) do
    created_at_time = NaiveDateTime.add(time, timezone_offset, :second)

    created_at_time
  end
end
