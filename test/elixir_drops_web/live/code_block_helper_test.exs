defmodule ElixirDropsWeb.CodeBlockHelperTest do
  use ExUnit.Case, async: true

  alias ElixirDropsWeb.CodeBlockHelper

  describe "has_code_block?/1" do
    test "returns true when code block is present" do
      body = "Some text\n```elixir\nIO.puts(\"hello\")\n```\nMore text"

      assert CodeBlockHelper.has_code_block?(body)
    end

    test "returns false when no code block is present" do
      body = "Some text without code block"

      assert CodeBlockHelper.has_code_block?(body) == false
    end
  end

  describe "compare_code_blocks/2" do
    test "returns :ok when code blocks are different" do
      old_body = "Some text\n```elixir\nIO.puts(\"hello\")\n```\nMore text"
      new_body = "Some text\n```elixir\nIO.puts(\"world\")\n```\nMore text"

      assert :ok = CodeBlockHelper.compare_code_blocks(old_body, new_body)
    end

    test "returns :ok when old body has no code block but new body does" do
      old_body = "Some text without code block"
      new_body = "Some text\n```elixir\nIO.puts(\"hello\")\n```\nMore text"

      assert :ok = CodeBlockHelper.compare_code_blocks(old_body, new_body)
    end

    test "returns {:cancel, reason} when code blocks are identical" do
      body = "Some text\n```elixir\nIO.puts(\"hello\")\n```\nMore text"

      assert {:cancel, "Code block unchanged"} = CodeBlockHelper.compare_code_blocks(body, body)
    end

    test "returns {:cancel, reason} when old body has code block but new body doesn't" do
      old_body = "Some text\n```elixir\nIO.puts(\"hello\")\n```\nMore text"
      new_body = "Some text without code block"

      assert {:cancel, "No code block found in updated body"} =
               CodeBlockHelper.compare_code_blocks(old_body, new_body)
    end

    test "returns {:cancel, reason} when neither body has code block" do
      old_body = "Some text without code block"
      new_body = "Some other text without code block"

      assert {:cancel, "No code block found"} =
               CodeBlockHelper.compare_code_blocks(old_body, new_body)
    end

    test "handles multiline code blocks" do
      old_body = """
      Some text
      ```elixir
      def hello do
        IO.puts("hello")
      end
      ```
      More text
      """

      new_body = """
      Some text
      ```elixir
      def hello do
        IO.puts("world")
      end
      ```
      More text
      """

      assert :ok = CodeBlockHelper.compare_code_blocks(old_body, new_body)
    end

    test "handles code blocks with different language specifications" do
      old_body = "Some text\n```elixir\nIO.puts(\"hello\")\n```\nMore text"
      new_body = "Some text\n```javascript\nconsole.log(\"hello\");\n```\nMore text"

      assert :ok = CodeBlockHelper.compare_code_blocks(old_body, new_body)
    end
  end
end
