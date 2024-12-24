defmodule ElixirDrops.DateTimeHelperTest do
  use ExUnit.Case, async: true

  alias ElixirDrops.DateTimeHelper

  describe "apply_timezone_offset/2" do
    test "returns correct time for a timezone offset" do
      base_time = ~N[2024-12-23 08:25:19]
      timezone_offset = -180

      expected_time = ~N[2024-12-23 08:22:19]
      assert DateTimeHelper.apply_timezone_offset(base_time, timezone_offset) == expected_time
    end
  end
end
