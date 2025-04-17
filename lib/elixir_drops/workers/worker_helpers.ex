defmodule ElixirDrops.WorkerHelpers do
  @moduledoc false

  @type body :: String.t()
  @type code_block :: String.t()

  @markdown_regex ~r/```(?:\w+\n)?(.+?)```/s

  @doc """
  Checks if a code block is present in the given body.
  """
  @spec check_for_code_block(body()) :: {:ok, code_block()} | {:error, String.t()}
  def check_for_code_block(body) do
    case Regex.run(@markdown_regex, body) do
      nil -> {:error, "No code block found"}
      [_full_match, code_block] -> {:ok, code_block}
    end
  end

  @spec has_code_block?(body()) :: boolean()
  def has_code_block?(body) do
    case check_for_code_block(body) do
      {:ok, _code_block} -> true
      {:error, _no_code_block} -> false
    end
  end
end
