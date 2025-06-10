defmodule ElixirDrops.StructuredData do
  @moduledoc """
  Handles structured data generation for ElixirDrops.
  """

  alias ElixirDrops.Drops.Drop

  @skipped_words ~w(
    about above after again against aren't because been before being below between both can't cannot could couldn't didn't does doesn't doing don't down during each from further hadn't hasn't have haven't having how how's i i'd i'll i'm i've if in into is isn't it it's its itself let's more most mustn't my myself once only or other ought ours ourselves over own same shan't she she'd she'll she's should shouldn't so some such than that that's the their theirs them themselves then there there's these they they'd they'll they're they've this those through under until very wasn't we'll we're we've were weren't what what's when when's where where's which while who's whom why's with won't would wouldn't you'd you'll you're you've your yours yourself yourselves
  )

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
    content_without_code = Regex.replace(~r/```elixir\n[\s\S]*?```/, body, "")

    content_without_code
    |> String.split(~r/\s+/)
    |> Enum.filter(fn word ->
      word =~ ~r/^[a-zA-Z][a-zA-Z0-9]*$/ and
        String.length(word) > 3 and
        String.downcase(word) not in @skipped_words
    end)
    |> Enum.uniq()
    |> Enum.join(", ")
  end
end
