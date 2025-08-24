defmodule ElixirDrops.MarkdownFormatter do
  @moduledoc """
  Formats drops as markdown for LLM consumption and Livebook integration.
  """

  use ElixirDropsWeb, :verified_routes

  alias ElixirDrops.Drops.Drop

  @type drop :: Drop.t()
  @type drops :: [Drop.t()]

  @spec format_drop(drop()) :: String.t()
  def format_drop(%Drop{} = drop) do
    # Use iolist for efficient string building
    IO.iodata_to_binary([
      "# ",
      drop.title,
      "\n\n",
      drop.body,
      "\n\n",
      "---\n\n",
      "Created by: ",
      drop.user.github_username,
      "\n",
      "Date: ",
      format_date(drop.inserted_at),
      "\n",
      "URL: ",
      url(~p"/d/#{drop.short_id}"),
      "\n"
    ])
  end

  @spec format_index(drops()) :: String.t()
  def format_index(drops) do
    header = [
      "# ElixirDrops Index\n\n",
      "A collection of Elixir tips, tricks, and code snippets shared by the community.\n\n",
      "---\n\n"
    ]

    drops_list = Enum.map(drops, &format_index_entry/1)

    IO.iodata_to_binary([header, Enum.intersperse(drops_list, "\n\n")])
  end

  defp format_index_entry(%Drop{} = drop) do
    # Extract first sentence or line as description
    description = extract_description(drop.body)

    [
      "## [",
      drop.title,
      "](",
      url(~p"/d/#{drop.short_id}") <> ".md",
      ")\n\n",
      description,
      "\n\n",
      "- Author: ",
      drop.user.github_username,
      "\n",
      "- Created: ",
      format_date(drop.inserted_at),
      "\n"
    ]
  end

  defp extract_description(body) do
    first_content_line =
      body
      |> String.split("\n")
      |> Enum.find(&(&1 != "" && !String.starts_with?(&1, "#")))

    case first_content_line do
      nil -> "No description available"
      line -> String.slice(line, 0, 200) <> if(String.length(line) > 200, do: "...", else: "")
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y")
  end
end
