defmodule ElixirDropsWeb.DropsLive.FormComponent do
  @moduledoc false

  use ElixirDropsWeb, :live_component

  import Phoenix.HTML.Form

  alias ElixirDrops.Drops
  alias ElixirDrops.S3Helper.Client
  alias ElixirDropsWeb.DropsComponents

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    changeset = Drops.change_drop(socket.assigns.drop)

    {:ok,
     socket
     |> assign_form(changeset)
     |> assign(:show_image_uploads_error?, false)}
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

  def handle_event("show-image-upload-error", _params, socket) do
    {:noreply, assign(socket, show_image_uploads_error?: true)}
  end

  def handle_event("upload-image", params, socket) do
    %{"image" => image_binary, "name" => name, "type" => type} = params
    filename = "#{Ecto.UUID.generate()}_#{name}"

    [_metadata, image] = String.split(image_binary, ",")

    decoded_image = Base.decode64!(image)

    case Client.upload_image(decoded_image, filename, type) do
      {:ok, url} ->
        {:reply, %{url: url}, socket}

      {:error, _reason} ->
        {:reply, %{error: "Failed to upload image"}, socket}
    end
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
