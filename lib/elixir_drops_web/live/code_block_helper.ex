defmodule ElixirDropsWeb.CodeBlockHelper do
  @moduledoc false

  @type body :: String.t()
  @type code_block :: String.t()

  @markdown_regex ~r/```(?:\w+\n)?(.+?)```/s

  @doc """
  Checks if a code block is present in the given body.
  Returns true if a code block is present, false otherwise.

  ## Examples

      iex> has_code_block?("defmodule Example do\n  def hello, do: \"Hello, world!\"\nend")
      true

      iex> has_code_block?("defmodule Example do")
      false
  """
  @spec has_code_block?(body()) :: boolean()
  def has_code_block?(body) do
    case check_for_code_block(body) do
      {:ok, _code_block} -> true
      {:error, _no_code_block} -> false
    end
  end

  @doc """
  Compares code blocks between two bodies.
  Returns :ok if code blocks are different or a code block is present in new_body but not in old_body.
  Returns {:cancel, reason} if code blocks are identical or if no code block is present in new_body.
  Only compares the first code block found in each body.

  ## Examples

      iex> compare_code_blocks(
      ...>   "defmodule Example do",
      ...>   "defmodule Example do\n  def hello, do: \"Hello, world!\"\nend"
      ...> )
      :ok

      iex> compare_code_blocks(
      ...>   "defmodule Example do",
      ...>   "defmodule Example do\n  def goodbye, do: \"Goodbye, world!\"\nend"
      ...> )
      {:cancel, "Code block unchanged"}

      iex> compare_code_blocks(
      ...>   "defmodule Example do",
      ...>   "defmodule Example do\n  def goodbye, do: \"Goodbye, world!\"\nend"
      ...> )
      {:cancel, "Code block unchanged"}

      iex> compare_code_blocks(
      ...>   "defmodule Example do",
      ...>   "defmodule Example do\n  def goodbye, do: \"Goodbye, world!\"\nend"
      ...> )
      {:cancel, "Code block unchanged"}
  """
  @spec compare_code_blocks(body(), body()) :: :ok | {:cancel, String.t()}
  def compare_code_blocks(old_body, new_body) do
    case {check_for_code_block(old_body), check_for_code_block(new_body)} do
      {{:ok, old_code_block}, {:ok, new_code_block}} when old_code_block != new_code_block ->
        :ok

      {{:error, _no_old_code_block}, {:ok, _new_code_block}} ->
        :ok

      {{:ok, _old_code_block}, {:ok, _old_unchanged_code_block}} ->
        {:cancel, "Code block unchanged"}

      {{:ok, _old_code_block}, {:error, _no_new_code_block}} ->
        {:cancel, "No code block found in updated body"}

      {{:error, _no_old_code_block}, {:error, _no_new_code_block}} ->
        {:cancel, "No code block found"}
    end
  end

  defp check_for_code_block(body) do
    case Regex.run(@markdown_regex, body) do
      nil -> {:error, "No code block found"}
      [_full_match, code_block] -> {:ok, code_block}
    end
  end
end
