defmodule ElixirDrops.ScreenshotGeneratorWorkerHelper do
  @moduledoc """
  Helper functions for our screenshot generator worker
  """

  @line_height 19.2
  @logo_offset_height 600
  @code_block_pattern ~r/```(?:\w+\n)?(.+?)```/s
  @max_height 843

  @spec calc_height(String.t()) :: integer()
  def calc_height(body) do
    case Regex.run(@code_block_pattern, body, capture: :first) do
      nil ->
        0

      [code_block] ->
        lines =
          code_block
          |> String.split("\n")
          |> length()

        code_height = trunc(@line_height * lines + @logo_offset_height)

        min(code_height, @max_height)
    end
  end
end
