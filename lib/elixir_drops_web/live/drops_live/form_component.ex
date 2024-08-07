defmodule ElixirDropsWeb.DropsLive.FormComponent do
  @moduledoc false

  use ElixirDropsWeb, :live_component

  import Phoenix.HTML.Form

  alias ElixirDrops.Drops
  alias ElixirDrops.S3Helper
  alias ElixirDropsWeb.DropsComponents

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
      {:ok, _drop} ->
        {
          :noreply,
          socket
          |> put_flash_message(socket.assigns.live_action)
          |> push_navigate(to: ~p"/#{socket.assigns.current_user.github_username}")
        }

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("upload-image", %{"type" => "image/" <> _rest = type} = params, socket) do
    %{"image" => image_binary, "name" => name} = params
    filename = "#{Ecto.UUID.generate()}_#{name}"

    [_metadata, image] = String.split(image_binary, ",")

    decoded_image = Base.decode64!(image)

    case S3Helper.upload_image(decoded_image, filename, type) do
      {:ok, url} ->
        {:noreply, push_event(socket, "image-upload-complete", %{url: url})}

      {:error, _reason} ->
        {:noreply, push_event(socket, "image-upload-error", %{})}
    end
  end

  # Invalid image type handling, maybe don't even allow them in  server -> Just deal with them in the UI
  def handle_event(:upload_image, _params, socket) do
    {:noreply, socket}
  end

  defp put_flash_message(socket, :new),
    do: put_flash(socket, :info, "Drop successfully created.")

  defp put_flash_message(socket, :edit),
    do: put_flash(socket, :info, "Drop successfully updated.")

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
end
