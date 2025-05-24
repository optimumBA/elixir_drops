defmodule ElixirDropsWeb.LiveHelpers do
  @moduledoc false

  import Phoenix.Component
  import Phoenix.LiveView

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) :: {:cont, map}

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
