defmodule ElixirDrops.DateTimeHelperTest do
  use ExUnit.Case, async: true

  alias ElixirDrops.DateTimeHelper

  describe "convert_to_relative_time/2" do
    test "gets relative time based on timezone" do
      now = DateTime.utc_now()
      naive_time_now = DateTime.to_naive(now)
      timezone = "UTC"

      assert DateTimeHelper.convert_to_relative_time(naive_time_now, timezone) ==
               "now"
    end
  end
end
