defmodule ElixirDrops.ScreenshotGeneratorWorkerHelperTest do
  use ExUnit.Case, async: true

  alias ElixirDrops.ScreenshotGeneratorWorkerHelper

  describe "calc_height/1" do
    test "returns 0 when body has no markdown code block" do
      body = "fjdjdjd\n"
      assert ScreenshotGeneratorWorkerHelper.calc_height(body) == "0"
    end

    test "caps the generated height at 2000 for long code blocks" do
      long_code = Enum.map_join(1..100, "\n", fn i -> "IO.puts(#{i})" end)

      body = """
      ```elixir
      #{long_code}
      ```
      """

      assert ScreenshotGeneratorWorkerHelper.calc_height(body) == "843"
    end

    test "for medium code blocks, returns a height that is between 0 and 2000" do
      long_code = Enum.map_join(1..50, "\n", fn i -> "IO.puts(#{i})" end)

      body = """
      ```elixir
      #{long_code}
      ```
      """

      height =
        body
        |> ScreenshotGeneratorWorkerHelper.calc_height()
        |> String.to_integer()

      assert height > 0 and height < 2000
    end
  end
end
