defmodule ElixirDropsWeb.SponsorRedirectController do
  use ElixirDropsWeb, :controller

  alias ElixirDrops.Sponsors
  alias ElixirDrops.Sponsors.Telemetry

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"placement" => placement}) do
    conn = put_resp_header(conn, "cache-control", "private, no-store")

    case Sponsors.destination_url(placement) do
      nil ->
        send_resp(conn, 404, "Not found")

      destination ->
        redirect_with_click(conn, placement, destination)
    end
  end

  # The destination is fixed before any write; the click write is one bounded
  # attempt (see ElixirDrops.Sponsors) and a failure never blocks the redirect.
  defp redirect_with_click(conn, placement, destination) do
    started = System.monotonic_time()
    outcome = maybe_record_click(conn, placement)
    conn = redirect(conn, external: destination)

    started
    |> Telemetry.elapsed_ms()
    |> Telemetry.redirect_duration(%{
      sponsor: "appsignal",
      placement: placement,
      outcome: outcome
    })

    conn
  end

  defp maybe_record_click(conn, placement) do
    if conn.private[:head_request] || prefetch?(conn) do
      Telemetry.event(:skipped, %{
        sponsor: "appsignal",
        placement: placement,
        kind: "click",
        reason: if(conn.private[:head_request], do: :head, else: :prefetch)
      })

      :not_counted
    else
      case Sponsors.record_click(placement,
             user: conn.assigns[:current_user],
             user_agent: List.first(get_req_header(conn, "user-agent"))
           ) do
        :ok -> :persisted
        :skipped -> :skipped
        {:error, _reason} -> :failed
      end
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
