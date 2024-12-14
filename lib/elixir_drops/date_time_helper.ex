defmodule ElixirDrops.DateTimeHelper do
  @moduledoc """
  Helper functions for date/time formatting.
  """

  @doc """
  Adds timezone offset and converts a NaiveDateTime to a relative time string.

  ## Examples

      iex> ElixirDrops.DateTimeHelper.convert_to_relative_time(~N[2019-01-01 00:00:00], 3600)
      "5 years ago"

  """
  @spec convert_to_relative_time(NaiveDateTime.t(), String.t()) :: String.t()
  def convert_to_relative_time(naive_time, timezone) do
    {:ok, datetime} = DateTime.from_naive(naive_time, "UTC")

    {:ok, time} = DateTime.shift_zone(datetime, timezone)

    Timex.format!(time, "{relative}", :relative)
  end
end
