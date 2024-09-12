defmodule ElixirDropsWeb.UserDropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsListComponent
  alias ElixirDropsWeb.UserDropLive.FormComponent

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(
       socket,
       :drop_filters,
       %{user_id: socket.assigns.current_user.id}
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    filters = %{
      drop_id: id,
      user_id: socket.assigns.current_user.id
    }

    assign_user_drop(socket, filters)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:drop, %Drop{})
    |> assign(:page_title, "Create Drop")
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:drop, nil)
    |> assign(:page_title, "ElixirDrops | #{socket.assigns.current_user.github_username}")
  end

  defp assign_user_drop(socket, filters) do
    case Drops.get_drop(filters) do
      nil ->
        socket
        |> assign(:drop, nil)
        |> push_navigate(to: ~p"/")

      %Drop{} = drop ->
        socket
        |> assign(:drop, drop)
        |> assign(:page_title, "Edit Drop")
    end
  end
end
