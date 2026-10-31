defmodule ElixirDropsWeb.CodeSnippetHelper do
  @moduledoc """
  Helper functions for our code snippet controller
  """

  @type code_block :: String.t()
  @type line_count :: integer()

  @spec count_lines(code_block()) :: line_count()
  def count_lines(code_block) do
    code_block
    |> String.split("\n")
    |> length()
  end
end
