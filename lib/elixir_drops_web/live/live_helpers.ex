defmodule ElixirDropsWeb.LiveHelpers do
  @moduledoc false

  import Phoenix.LiveView
  import Phoenix.Component

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) :: {:cont, map}
  def on_mount(:assign_timezone, _params, _session, socket) do
    timezone =
      cond do
        connected?(socket) ->
          Phoenix.LiveView.get_connect_params(socket)["timezone"]

        Map.has_key?(socket.assigns, :timezone) ->
          socket.assigns.timezone

        true ->
          0
      end

    {:cont, assign(socket, :timezone, timezone)}
  end

  def on_mount(:maybe_show_welcome_message, _params, _session, socket) do
    show_welcome_message? =
      cond do
        connected?(socket) ->
          Phoenix.LiveView.get_connect_params(socket)["show_welcome_message"] == "true"

        Map.has_key?(socket.assigns, :show_welcome_message?) ->
          socket.assigns.show_welcome_message?

        true ->
          true
      end

    {:cont, assign(socket, :show_welcome_message?, show_welcome_message?)}
  end
end
