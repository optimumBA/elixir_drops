  @spec generate() :: short_unique_string()
  def generate do
    @short_unique_string_allowed_chars
    |> String.to_charlist()
    |> Enum.shuffle()
    |> Enum.take(8)
    |> List.to_string()
  end
