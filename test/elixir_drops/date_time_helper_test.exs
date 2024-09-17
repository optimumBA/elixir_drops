defmodule ElixirDrops.DateTimeHelperTest do
  use ExUnit.Case, async: true

  alias ElixirDrops.DateTimeHelper

  describe "convert_to_relative_time/2" do
    test "adds timezone offset and converts to relative time" do
      now = DateTime.utc_now()
      naive_time_now = DateTime.to_naive(now)
      timezone_offset = 3600

      assert DateTimeHelper.convert_to_relative_time(naive_time_now, timezone_offset) ==
               "in 59 minutes"
    end
  end
end
