defmodule ElixirDrops.WorkerHelpersTest do
  use ElixirDrops.DataCase, async: false

  alias ElixirDrops.WorkerHelpers

  describe "check_for_code_block/1" do
    test "returns {:ok, code_block} when a code block is found" do
      assert {:ok, "IO.puts(\"Hello, World!\")"} =
               WorkerHelpers.check_for_code_block("```elixir\nIO.puts(\"Hello, World!\")```")
    end

    test "returns {:error, \"No code block found\"} when no code block is found" do
      assert {:error, "No code block found"} =
               WorkerHelpers.check_for_code_block("Hello, World!")
    end
  end
end
