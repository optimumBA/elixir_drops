defmodule ElixirDropsWeb.DropsLiveHelpers do
  @moduledoc false

  @spec convert_time(NaiveDateTime.t(), integer()) :: String.t()
  def convert_time(time, timezone_offset) do
    {:ok, created_at_time} =
      time
      |> NaiveDateTime.add(timezone_offset, :second)
      |> Timex.format("{relative}", :relative)

    created_at_time
  end
end
