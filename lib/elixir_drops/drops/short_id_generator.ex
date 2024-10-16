defmodule ElixirDrops.Drops.ShortIdGenerator do
  @moduledoc """
  Generate a short unique string.
  """

  @allowed_chars "ABCDEFGHJKLMNPQRTUVWXYZabcdefghijkmnopqrstuvwxyz12346789"

  @type short_id_string :: String.t()

  @doc """
  Generates a short id string.

  ## Examples

      iex> generate_short_id()
      "vPfoDMdY"

  """
  @spec generate() :: short_id_string()
  def generate do
    @allowed_chars
    |> String.to_charlist()
    |> Enum.shuffle()
    |> Enum.take(8)
    |> List.to_string()
  end
end
