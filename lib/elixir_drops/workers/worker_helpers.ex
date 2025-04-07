defmodule ElixirDrops.WorkerHelpers do
  @moduledoc false

  @markdown_regex ~r/```(?:\w+\n)?(.+?)```/s

  @doc """
  Checks if a code block is present in the given body.
  """
  @spec check_for_code_block(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def check_for_code_block(body) do
    case Regex.run(@markdown_regex, body) do
      nil -> {:error, "No code block found"}
      [_full_match, code_block] -> {:ok, code_block}
    end
  end
end
