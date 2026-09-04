defmodule ElixirDropsWeb.SponsorRedirectController do
  use ElixirDropsWeb, :controller

  alias ElixirDrops.Sponsors

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"placement" => placement}) do
    conn = put_resp_header(conn, "cache-control", "private, no-store")

    case Sponsors.destination_url(placement) do
      nil ->
        send_resp(conn, 404, "Not found")

      destination ->
        unless conn.private[:head_request] || prefetch?(conn) do
          Sponsors.record_click(placement,
            user: conn.assigns[:current_user],
            user_agent: List.first(get_req_header(conn, "user-agent"))
          )
        end

        redirect(conn, external: destination)
    end
  end

  defp prefetch?(conn) do
    Enum.any?(~w(purpose sec-purpose x-moz), fn header ->
      Enum.any?(get_req_header(conn, header), fn value ->
        String.contains?(String.downcase(value), ["prefetch", "prerender", "preview"])
      end)
    end)
  end
end
