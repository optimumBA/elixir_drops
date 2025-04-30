defmodule ElixirDrops.ScreenshotGeneratorWorkerHelper do
  @moduledoc """
  Helper functions for our screenshot generator worker
  """

  @line_height 19.2
  @logo_offset_height 600
  @code_block_pattern ~r/```(?:\w+\n)?(.+?)```/s
  @max_height 843
  @internal_min_height 120
  @internal_line_height 35
  @internal_padding 20
  @internal_max_height 1100

  @spec calc_height(String.t()) :: integer()
  def calc_height(body) do
    case Regex.run(@code_block_pattern, body, capture: :first) do
      nil ->
        0

      code_block ->
        lines =
          code_block
          |> Enum.at(0)
          |> String.split("\n")
          |> length()

        code_height = trunc(@line_height * lines + @logo_offset_height)

        min(code_height, @max_height)
    end
  end

  @spec calc_height_internal(String.t()) :: integer()
  def calc_height_internal(body) do
    case Regex.run(@code_block_pattern, body, capture: :first) do
      nil ->
        0

      [code_block] ->
        lines = length(String.split(code_block, ~r/\n/))
        raw_size = @internal_line_height * lines + @internal_padding

        size =
          raw_size
          |> max(@internal_min_height)
          |> min(@internal_max_height)

        round(size / 50) * 50
    end
  end
end
