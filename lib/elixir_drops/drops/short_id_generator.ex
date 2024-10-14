defmodule ElixirDrops.Drops.ShortIdGenerator do
  @moduledoc """
  Generate a short unique string.
  """

  @short_unique_string_allowed_chars "ABCDEFGHJKLMNPQRTUVWXYZabcdefghijkmnopqrstuvwxyz12346789"

  @type short_id_string :: String.t()

  @doc """
  Generates a short id string.

  ## Examples

      iex> generate_short_id()
      "vPfoDMdY"

  """
  @spec generate() :: short_unique_string()
  def generate do
    @short_unique_string_allowed_chars
    |> String.to_charlist()
    |> Enum.shuffle()
    |> Enum.take(8)
    |> List.to_string()
  end
end
