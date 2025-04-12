defmodule ElixirDropsWeb.CodeSnippetHelper do
  @moduledoc """
  Helper functions for our code snippet controller
  """

  @spec calc_lines(String.t()) :: integer()
  def calc_lines(code_block) do
    code_block
    |> String.split("\n")
    |> length()
  end
end
