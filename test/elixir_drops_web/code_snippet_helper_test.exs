defmodule ElixirDropsWeb.CodeSnippetHelperTest do
  use ExUnit.Case, async: true

  alias ElixirDropsWeb.CodeSnippetHelper

  describe "count_lines/1" do
    test "returns the number of lines in a code block" do
      code_block = "```elixir\n  defp handle_drop_retrieval(conn, id) d\n```"
      assert CodeSnippetHelper.count_lines(code_block) == 3
    end
  end
end
