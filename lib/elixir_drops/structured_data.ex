defmodule ElixirDrops.StructuredData do
  @moduledoc """
  Handles structured data generation for ElixirDrops.
  """

  alias ElixirDrops.Drops.Drop

  @doc """
  Generates JSON-LD structured data for a drop.
  """

  @spec generate_drop_json_ld(Drop.t()) :: String.t()
  def generate_drop_json_ld(%Drop{} = drop) do
    Jason.encode!(%{
      "@context" => "https://schema.org",
      "@type" => "Elixir Drop",
      "headline" => drop.title,
      "image" => [
        %{
          "@type" => "ImageObject",
          "url" => drop.screenshot.meta_url,
          "width" => "1200",
          "height" => "630"
        }
      ],
      "author" => %{
        "@type" => "Person",
        "name" => drop.user.name,
        "url" => "https://github.com/#{drop.user.github_username}",
        "image" => drop.user.avatar
      },
      "publisher" => %{
        "@type" => "Organization",
        "name" => "ElixirDrops",
        "logo" => %{
          "@type" => "ImageObject",
          "url" => "https://elixirdrops.net/images/logo.png"
        }
      },
      "datePublished" => NaiveDateTime.to_iso8601(drop.inserted_at),
      "dateModified" => NaiveDateTime.to_iso8601(drop.updated_at),
      "articleBody" => drop.body,
      "url" => "https://elixirdrops.net/d/#{drop.short_id}",
      "mainEntityOfPage" => %{
        "@type" => "WebPage",
        "@id" => "https://elixirdrops.net/d/#{drop.short_id}"
      },
      "description" => String.slice(drop.body, 0..160),
      "keywords" => extract_keywords(drop.body)
    })
  end

  defp extract_keywords(body) do
    code_blocks =
      Regex.scan(~r/```elixir\n([\s\S]*?)```/, body)

    terms =
      Enum.map(code_blocks, fn [_, code] ->
        code
        |> String.split(~r/\s+/)
        |> Enum.filter(&(&1 =~ ~r/^[A-Z][a-zA-Z0-9]*$/))
        |> Enum.uniq()
      end)

    terms
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.join(", ")
  end
end
