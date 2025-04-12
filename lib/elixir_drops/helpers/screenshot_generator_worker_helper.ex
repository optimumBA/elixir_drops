defmodule ElixirDrops.ScreenshotGeneratorWorkerHelper do
  @moduledoc """
  Helper functions for our screenshot generator worker
  """

  @line_height 19.2
  @logo_offset_height 600
  @markdown_regex ~r/```(?:\w+\n)?(.+?)```/s
  @max_height 843

  @spec calc_height(String.t()) :: String.t()
  def calc_height(body) do
    case Regex.run(@markdown_regex, body, capture: :first) do
      nil ->
        "0"

      regex ->
        lines =
          regex
          |> Enum.at(0)
          |> String.split("\n")
          |> length()

        code_height = @line_height * lines + @logo_offset_height

        code_height =
          if code_height >= @max_height do
            @max_height
          else
            code_height
          end

        code_height
        |> trunc()
        |> Integer.to_string()
    end
  end
end
