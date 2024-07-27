defmodule ElixirDrops.DateTimeHelperTest do
  use ExUnit.Case, async: true

  alias ElixirDrops.DateTimeHelper

  describe "convert_to_relative_time/2" do
    test "adds timezone offset and converts to relative time" do
      assert DateTimeHelper.convert_to_relative_time(~N[2019-01-01 00:00:00], 3600) ==
               "5 years ago"
    end
  end
end
