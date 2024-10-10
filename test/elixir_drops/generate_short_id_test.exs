defmodule ElixirDrops.GenerateShortIdTest do
  use ExUnit.Case, async: true

  alias ElixirDrops.GenerateShortId

  describe "generate_short_id/0" do
    test "generates a short id" do
      assert is_binary(GenerateShortId.generate_short_id())
      assert String.length(GenerateShortId.generate_short_id()) == 8
      assert String.match?(GenerateShortId.generate_short_id(), ~r/^[A-Za-z0-9]+$/)
      assert GenerateShortId.generate_short_id() != GenerateShortId.generate_short_id()
    end
  end
end
