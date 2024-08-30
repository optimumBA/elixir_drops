defmodule ElixirDropsWeb.DropLive.FormComponent do
  @moduledoc false

  use ElixirDropsWeb, :live_component

  import Phoenix.HTML.Form

  alias ElixirDrops.Drops
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.DropLive.Icons

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    changeset = Drops.change_drop(socket.assigns.drop)

    {:ok,
     socket
     |> assign_form(changeset)
     |> assign_tags(socket.assigns.live_action)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("validate", %{"drop" => drop_params}, socket) do
    changeset =
      socket.assigns.drop
      |> Drops.change_drop(drop_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  # Check number of tags -> Add error messages to form
  # For Max, check from frontend, prevent user from typing more
  # Maybe pass the tags as a list from here, so no one has wonder what to get from map
  # Test number of tags allowed and that the tags are unique
  # Tag in the show and list cards
  def handle_event("save", %{"drop" => drop_params}, socket) do
    tags = socket.assigns.tags
    drop_params = Map.put(drop_params, "tags", tags)

    case create_or_update_drop(socket, socket.assigns.live_action, drop_params) do
      {:ok, _drop} ->
        {
          :noreply,
          push_navigate(
            socket,
            to: ~p"/profile"
          )
        }

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("update-tags", %{"tags" => tags}, socket) do
    {:noreply, assign(socket, :tags, tags)}
  end

  defp create_or_update_drop(socket, :edit, drop_params) do
    Drops.update_drop(
      socket.assigns.drop,
      socket.assigns.current_user,
      drop_params
    )
  end

  defp create_or_update_drop(socket, :new, drop_params) do
    Drops.create_drop(
      socket.assigns.drop,
      socket.assigns.current_user,
      drop_params
    )
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp assign_tags(socket, :new), do: assign(socket, :tags, "")

  defp assign_tags(socket, :edit) do
    tags =
      socket.assigns.drop.tags
      |> Enum.map(& &1.name)
      |> Enum.join(", ")

    assign(socket, :tags, tags)
  end
end
