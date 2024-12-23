defmodule ElixirDrops.DateTimeHelperTest do
  use ExUnit.Case, async: true

  alias ElixirDrops.DateTimeHelper

  describe "convert_to_relative_time/2" do
    test "returns correct time for a timezone offset" do
      base_time = ~N[2024-12-23 08:25:19]
      # -1 hour in seconds
      timezone_offset = -180

      expected_time = ~N[2024-12-23 08:22:19]
      assert DateTimeHelper.convert_to_relative_time(base_time, timezone_offset) == expected_time
    end
  end
end
