defmodule ElixirDropsWeb.ArchiveController do
  use ElixirDropsWeb, :controller

  alias ElixirDrops.Drops

  @archive_description "Browse every Elixir, Phoenix, and OTP tip published on ElixirDrops."

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    archive_url = url(~p"/archive")

    groups =
      Drops.list_all_drops()
      |> Enum.chunk_by(&{&1.inserted_at.year, &1.inserted_at.month})
      |> Enum.map(fn [first | _drops] = group ->
        %{label: Calendar.strftime(first.inserted_at, "%B %Y"), drops: group}
      end)

    conn
    |> assign(:page_title, "All drops | ElixirDrops")
    |> assign(:seo_attributes, %{
      canonical_url: archive_url,
      description: @archive_description,
      title: "All drops | ElixirDrops",
      type: "website",
      url: archive_url
    })
    |> render(:index, groups: groups)
  end
end
