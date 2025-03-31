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
        maybe_enqueue_screenshot_generation(socket, drop)

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

  defp enqueue_seo_screenshot_creation(drop_id, old_body, action) do
    %{"drop_id" => drop_id, "old_body" => old_body, "action" => action}
    |> ScreenshotGeneratorWorker.new()
    |> Oban.insert()
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp maybe_enqueue_screenshot_generation(socket, drop) do
    case socket.assigns do
      %{live_action: :edit, drop: %{body: old_body}} when old_body != drop.body ->
        enqueue_seo_screenshot_creation(drop.id, old_body, :edit)

        send(self(), :screenshot_generation_started)

        {:noreply, socket}

      %{live_action: :edit, drop: %{body: old_body}} when old_body == drop.body ->
        socket = push_navigate(socket, to: ~p"/profile")
        {:noreply, socket}

      %{live_action: :new} ->
        enqueue_seo_screenshot_creation(drop.id, nil, :new)

        send(self(), :screenshot_generation_started)

        {:noreply, socket}

      _assigns ->
        {:noreply, socket}
    end
  end
end
