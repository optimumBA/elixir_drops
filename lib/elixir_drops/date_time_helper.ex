defmodule ElixirDrops.DateTimeHelper do
  @moduledoc """
  Helper functions for date/time formatting.
  """

  @doc """
  Adds timezone offset to NaiveDateTime.

  ## Examples

      iex> ElixirDrops.DateTimeHelper.apply_timezone_offset(~N[2019-01-01 00:00:00], 3600)
      ~N[2019-01-01 01:00:00]

  """
  @spec apply_timezone_offset(NaiveDateTime.t(), integer()) :: NaiveDateTime.t()
  def apply_timezone_offset(time, timezone_offset) do
    NaiveDateTime.add(time, timezone_offset, :second)
  end
end
