defmodule ElixirDrops.StructuredData do
  @moduledoc """
  Handles structured data generation for ElixirDrops.
  """

  alias ElixirDrops.Drops.Drop

  @priority_keywords ~w(
  elixir erlang liveview phoenix ash mount handle_event handle_info handle_params socket assigns push_event push_navigate push_patch component slot phx-click phx-change phx-submit phx-blur phx-focus phx-keydown phx-window plug router endpoint controller action ecto schema changeset repo migration query preload test assert refute describe setup context
  pattern matching operator functional programming immutability recursion tail_recursion
  genserver supervisor otp application behaviour module defstruct defimpl defprotocol rescue catch spawn send receive process pid task agent enum stream map filter reduce flatmap zip
  error tuple atom string binary bitstring list struct keyword_list charlist conn params session flash cookies headers render redirect assign pubsub broadcast subscribe telemetry logging config env compile mix hex deps umbrella release jason poison httpoison finch req gettext i18n locale csrf_token form_for form_with validates_required live_redirect live_patch connected disconnected temporary_assigns update handle_assign_new macro quote unquote ast metaprogramming doc spec typespec dialyzer credo websocket transport channel topic guardian auth token jwt session_storefloki hound wallaby integration_test broadway flow genstage rate_limiting cluster libcluster distributed nodes cowboy ranch plug_cowboy nimble_parsec nimble_csv timex
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
    |> String.downcase()
    |> String.split(~r/\s+/)
    |> Enum.filter(fn word ->
      word in Enum.map(@priority_keywords, &String.downcase/1)
    end)
    |> Enum.take(10)
    |> Enum.join(", ")
  end
end
