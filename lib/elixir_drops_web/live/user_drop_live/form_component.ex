defmodule ElixirDropsWeb.UserDropLive.FormComponent do
  @moduledoc false

  use ElixirDropsWeb, :live_component

  import Phoenix.HTML.Form

  alias ElixirDrops.Drops
  alias ElixirDrops.Workers.ScreenshotGeneratorWorker
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.Icons

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    changeset = Drops.change_drop(socket.assigns.drop)

    {:ok, assign_form(socket, changeset)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("validate", %{"drop" => drop_params}, socket) do
    changeset =
      socket.assigns.drop
      |> Drops.change_drop(drop_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"drop" => drop_params}, socket) do
    case create_or_update_drop(socket, socket.assigns.live_action, drop_params) do
      {:ok, drop} ->
        if socket.assigns.live_action == :edit do
          old_drop = socket.assigns.drop

          if old_drop.body != drop.body do
            enqueue_seo_screenshot_creation(drop.id)
          end
        else
          enqueue_seo_screenshot_creation(drop.id)
        end

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

  defp enqueue_seo_screenshot_creation(drop_id) do
    %{"drop_id" => drop_id}
    |> ScreenshotGeneratorWorker.new()
    |> Oban.insert()
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
