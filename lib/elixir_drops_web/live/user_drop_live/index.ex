defmodule ElixirDropsWeb.UserDropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropsListHelper
  alias ElixirDropsWeb.UserDropLive.FormComponent

  require Logger
  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
     |> assign(:drop_filters, %{user_id: socket.assigns.current_user.id})
     |> assign(:end_of_timeline?, false)
     |> DropsListHelper.assign_drops()}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl Phoenix.LiveView
  def handle_event("next-page", _params, socket) do
    filters = %{older_than: socket.assigns.last_drop}

    {
      :noreply,
      DropsListHelper.maybe_insert_drops(socket, filters, socket.assigns.last_drop)
    }
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, socket}
  end

  def handle_event("prev-page", _params, socket) do
    filters = %{newer_than: socket.assigns.first_drop}

    {
      :noreply,
      DropsListHelper.maybe_insert_drops(socket, filters, socket.assigns.first_drop, at: 0)
    }
  end

  def handle_event(
        "close_editor",
        %{"pop-up-message" => pop_up_message_id},
        socket
      ) do
    Logger.info("Closing editor...")

    %JS{}
    |> JS.add_class("hidden", to: "##{pop_up_message_id}")
    |> JS.remove_class("show-pop-up", to: ".drops-container")
    |> JS.remove_class("show-pop-up", to: ".drop-form")

    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  defp apply_action(socket, :edit, %{"short_id" => short_id}) do
    filters = %{
      short_id: short_id,
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
