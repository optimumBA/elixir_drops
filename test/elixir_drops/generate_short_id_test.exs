defmodule ElixirDrops.GenerateShortIdTest do
  use ExUnit.Case, async: true

  alias ElixirDrops.Drops.ShortIdGenerator

  describe "generate_short_id/0" do
    test "generates a short id" do
      assert is_binary(ShortIdGenerator.generate())
      assert String.length(ShortIdGenerator.generate()) == 8
      assert String.match?(ShortIdGenerator.generate(), ~r/^[A-Za-z0-9]+$/)
      assert ShortIdGenerator.generate() != ShortIdGenerator.generate()
    end
  end
end
