defmodule ElixirDrops.StructuredData do
  @moduledoc """
  Handles structured data generation for ElixirDrops.
  """

  alias ElixirDrops.Drops.Drop

  @dangerous_patterns ~r/(script|javascript|vbscript|alert)/i
  @skipped_words ~w(
    about above after again against aren't because been before being below between both can't cannot could couldn't didn't does doesn't doing don't down during each from further hadn't hasn't have haven't having how's into isn't it's its itself let's more most mustn't myself once only other ought ours ourselves over same shan't she'd she'll she's should shouldn't some such than that that's the their theirs them themselves then there there's these they they'd they'll they're they've this those through under until very wasn't we'll we're we've were weren't what what's when when's where where's which while who's whom why's with won't would wouldn't you'd you'll you're you've your yours yourself yourselves script javascript vbscript alert
  )

  @doc """
  Generates JSON-LD structured data for a drop.
  """
  @spec generate_drop_json_ld(Drop.t()) :: String.t()
  def generate_drop_json_ld(%Drop{} = drop) do
    image_url =
      (drop.screenshot && drop.screenshot.meta_url) ||
        "https://elixirdrops.net/images/seo_default_image.png"

    user_avatar = drop.user.avatar
    user_name = drop.user.name || "Anonymous"

    safe_title = escape_script_tags(drop.title)

    safe_description =
      drop.body
      |> escape_script_tags()
      |> String.slice(0..160)

    Jason.encode!(%{
      "@context" => "https://schema.org",
      "@type" => "Article",
      "headline" => safe_title,
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
      "articleBody" => safe_description,
      "url" => "https://elixirdrops.net/d/#{drop.short_id}",
      "mainEntityOfPage" => %{
        "@type" => "WebPage",
        "@id" => "https://elixirdrops.net/d/#{drop.short_id}"
      },
      "description" => safe_description,
      "keywords" => extract_keywords(drop.body)
    })
  end

  defp escape_script_tags(text) when is_binary(text) do
    text
    |> String.replace(~r/<\/script>/i, "<\\/script>", global: true)
    |> String.replace(~r/<script/i, "<\\u0073cript", global: true)
    |> String.replace(~r/javascript:/i, "javascript\\u003a", global: true)
    |> String.replace(~r/vbscript:/i, "vbscript\\u003a", global: true)
    |> String.replace(~r/data:/i, "data\\u003a", global: true)
    |> String.replace(~r/&lt;\/script&gt;/i, "&lt;\\/script&gt;", global: true)
  end

  defp escape_script_tags(_text), do: ""

  defp extract_keywords(text) when is_binary(text) do
    text_without_code = Regex.replace(~r/```[\s\S]*?```/, text, " ")

    text_without_code
    |> String.split(~r/\s+/)
    |> Enum.filter(fn word ->
      cleaned_word =
        word
        |> String.downcase()
        |> String.replace(~r/[^\w]/, "")

      String.length(cleaned_word) > 3 and
        cleaned_word not in @skipped_words and
        not Regex.match?(@dangerous_patterns, cleaned_word)
    end)
    |> Enum.uniq()
    |> Enum.take(30)
  end

  defp extract_keywords(_text), do: []
end
