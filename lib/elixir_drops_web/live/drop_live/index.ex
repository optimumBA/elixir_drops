defmodule ElixirDropsWeb.DropLive.Index do
  use ElixirDropsWeb, :live_view

  alias ElixirDrops.Drops
  alias ElixirDrops.Drops.Drop
  alias Phoenix.LiveView.AsyncResult
  alias ElixirDrops.S3Helper.Client

  alias ElixirDropsWeb.DropLive.DropComponents
  alias ElixirDropsWeb.DropLive.FormComponent

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Drops.subscribe()
    end

    {
      :ok,
      socket
      |> stream_configure(:drops, dom_id: &"drop-#{&1.id}")
      |> assign(:end_of_timeline?, false)
      |> assign(:new_drops?, false)
      |> assign(:show_user_drops?, false)
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({Drops, [:drop, :created], _drop}, socket) do
    {:noreply, assign(socket, :new_drops?, true)}
  end

  @impl true
  def handle_event("next-page", _params, socket) do
    socket = insert_drops(socket, %{older_than: socket.assigns.last_drop})

    {
      :noreply,
      assign(socket, :end_of_timeline?, is_nil(socket.assigns.last_drop))
    }
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, socket}
  end

  def handle_event("prev-page", _params, socket) do
    socket = insert_drops(socket, %{newer_than: socket.assigns.first_drop}, at: 0)

    {
      :noreply,
      assign(socket, :end_of_timeline?, is_nil(socket.assigns.first_drop))
    }
  end

  def handle_event("refresh-drops", _params, socket) do
    {:noreply, assign_drops(socket)}
  end

  def handle_event("show-image-upload-error", _params, socket) do
    {:noreply, assign(socket, show_image_uploads_error?: true)}
  end

  @impl Phoenix.LiveView
  def handle_event("upload-image", params, socket) do
    {:noreply,
     socket
     |> assign(:drop_image, AsyncResult.loading())
     |> start_image_upload(params)}
  end

  def start_image_upload(socket, params) do
    %{"image" => image_binary, "name" => name, "type" => type} = params

    filename = "#{Ecto.UUID.generate()}_#{name}"

    [_metadata, image] = String.split(image_binary, ",")

    decoded_image = Base.decode64!(image)

    start_async(socket, :image_upload_task, fn ->
      case Client.upload_image(decoded_image, filename, type) do
        {:ok, url} ->
          {:reply, %{url: url}, socket}

        {:error, _reason} ->
          {:reply, %{error: "Failed to upload image"}, socket}
      end
    end)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    case Drops.get_drop(id) do
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

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:drop, %Drop{})
    |> assign(:page_title, "Create Drop")
  end

  defp apply_action(socket, :index, %{"user_name" => user_name}) do
    user_id = socket.assigns.current_user.id

    socket
    |> assign(:drop, nil)
    |> assign(:page_title, "ElixirDrops | #{user_name}")
    |> assign(:show_user_drops?, true)
    |> assign_drops(%{user_id: user_id})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:drop, nil)
    |> assign(:page_title, "ElixirDrops")
    |> assign(:show_user_drops?, false)
    |> assign_drops()
  end

  defp assign_drops(socket, filters \\ %{}) do
    drops = Drops.list_drops(filters)
    first_drop = List.first(drops)
    last_drop = List.last(drops)

    socket
    |> stream(:drops, drops, reset: true)
    |> assign(:first_drop, first_drop)
    |> assign(:last_drop, last_drop)
  end

  defp insert_drops(socket, filters, opts \\ []) do
    drops =
      socket
      |> maybe_filter_user_drops(filters)
      |> Drops.list_drops()

    first_drop = List.first(drops)
    last_drop = List.last(drops)

    socket
    |> stream_insert_many(:drops, drops, opts)
    |> assign(:first_drop, first_drop)
    |> assign(:last_drop, last_drop)
  end

  defp maybe_filter_user_drops(socket, filters) do
    if socket.assigns.show_user_drops? do
      Map.put(filters, :user_id, socket.assigns.current_user.id)
    else
      filters
    end
  end

  @impl true
  def handle_async(:image_upload_task, {:ok, uploaded_image}, socket) do
    %{drop_image: drop_image} = socket.assigns

    {:noreply,
     socket
     |> put_flash(:info, "Image uploaded successfully")
     |> assign(:uploaded_image, AsyncResult.ok(drop_image, uploaded_image))}
  end

  @impl true
  def handle_async(:image_upload_task, {:exit, reason}, socket) do
    %{drop_image: drop_image} = socket.assigns

    {:noreply,
     socket
     |> put_flash(:info, "Image upload failed")
     |> assign(:uploaded_image, AsyncResult.failed(drop_image, {:exit, reason}))}
  end
end
