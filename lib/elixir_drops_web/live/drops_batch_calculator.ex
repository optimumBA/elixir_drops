defmodule ElixirDropsWeb.DropsBatchCalculator do
  @moduledoc """
  Calculates optimal batch sizes for drops based on viewport dimensions.

  This module determines how many drops should be loaded in each batch
  based on the user's viewport size, ensuring smooth infinite scrolling
  with appropriate data loading for different screen sizes.
  """

  @spec calculate_batch_size(non_neg_integer(), non_neg_integer()) :: pos_integer()
  def calculate_batch_size(viewport_width, viewport_height) do
    columns = calculate_columns(viewport_width)
    rows_in_viewport = calculate_visible_rows(viewport_height)
    cards_visible = max(columns * rows_in_viewport, columns * 2)

    batch_size = cards_visible + columns

    batch_size
    |> max(6)
    |> min(40)
  end

  defp calculate_columns(width) when width <= 480, do: 1
  defp calculate_columns(width) when width <= 768, do: 2
  defp calculate_columns(width) when width <= 1400, do: 3
  defp calculate_columns(width) when width <= 1800, do: 4
  defp calculate_columns(_width), do: 5

  defp calculate_visible_rows(height) do
    average_card_height = 350
    available_height = height - 200
    max(floor(available_height / average_card_height), 1)
  end
end
