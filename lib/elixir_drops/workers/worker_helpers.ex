defmodule ElixirDrops.WorkerHelpers do
  @markdown_regex ~r/```(?:\w+\n)?(.+?)```/s

  @spec check_for_code_block(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def check_for_code_block(body) do
    case Regex.run(@markdown_regex, body, capture: :first) do
      nil -> {:error, "No code block found"}
      code_block -> {:ok, code_block}
    end
  end
end
