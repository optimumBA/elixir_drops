defmodule ElixirDrops.GenerateShortId do
  @moduledoc """
  Generate a short unique string.
  """

  @short_unique_string_allowed_chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

  @type short_unique_string :: String.t()

  @doc """
  Generates a short id string.

  ## Examples

      iex> generate_short_id()
      "vPfoDMdY"

  """
  @spec generate_short_id() :: short_unique_string()
  def generate_short_id do
    @short_unique_string_allowed_chars
    |> String.to_charlist()
    |> Enum.shuffle()
    |> Enum.take(8)
    |> List.to_string()
  end
end
