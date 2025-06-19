defmodule ElixirDrops.StructuredData do
  @moduledoc """
  Handles structured data generation for ElixirDrops.
  """

  alias ElixirDrops.Drops.Drop

  @skipped_words ~w(
    about above after again against aren't because been before being below between both can't cannot could couldn't didn't does doesn't doing don't down during each from further hadn't hasn't have haven't having how's into isn't it's its itself let's more most mustn't myself once only other ought ours ourselves over same shan't she'd she'll she's should shouldn't some such than that that's the their theirs them themselves then there there's these they they'd they'll they're they've this those through under until very wasn't we'll we're we've were weren't what what's when when's where where's which while who's whom why's with won't would wouldn't you'd you'll you're you've your yours yourself yourselves
  )

  @doc """
  Generates JSON-LD structured data for a drop.
  """
  @spec generate_drop_json_ld(Drop.t()) :: String.t()
  def generate_drop_json_ld(%Drop{} = drop) do
    image_url = drop.screenshot.meta_url || "https://elixirdrops.net/images/seo_default_image.png"
    user_avatar = drop.user.avatar
    user_name = drop.user.name || "Anonymous"

    Jason.encode!(%{
      "@context" => "https://schema.org",
      "@type" => "Article",
      "headline" => drop.title,
      "image" => [
        %{
          "@type" => "ImageObject",
          "url" => image_url,
          "width" => "1200",
          "height" => "630"
        }
      ],
      "author" => %{
        "@type" => "Person",
        "name" => user_name,
        "url" => "https://github.com/#{drop.user.github_username}",
        "image" => user_avatar
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

  defp extract_keywords(text) do
    text_without_code = Regex.replace(~r/```[\s\S]*?```/, text, " ")

    text_without_code
    |> String.split(~r/\s+/)
    |> Enum.filter(fn word ->
      String.length(word) > 3 and
        String.downcase(word) not in @skipped_words
    end)
    |> Enum.uniq()
    |> Enum.take(30)
  end
end
