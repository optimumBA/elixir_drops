defmodule ElixirDropsWeb.UserDropLive.FormComponent do
  @moduledoc false

  use ElixirDropsWeb, :live_component

  import Phoenix.HTML.Form

  alias ElixirDrops.Drops
  alias ElixirDrops.Workers.ScreenshotGeneratorWorker
  alias ElixirDrops.Workers.SitemapGeneratorWorker
  alias ElixirDropsWeb.CodeBlockHelper
  alias ElixirDropsWeb.DropComponents
  alias ElixirDropsWeb.Icons

  @impl Phoenix.LiveComponent
  def update(%{screenshot: %{progress_value: 0}} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> push_event("screenshot_generation_started", %{})}
  end

  def update(%{screenshot: screenshot} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> push_event("screenshot_progress_update", %{
       drop_short_id: screenshot.drop_short_id,
       progress: screenshot.progress_value,
       status: screenshot.status,
       url: screenshot.url
     })}
  end

  def update(assigns, socket) do
    changeset = Drops.change_drop(assigns.drop)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:screenshot, fn ->
       %{
         drop_short_id: "",
         progress_value: 0,
         status: :skipped,
         url: nil
       }
     end)
     |> assign_form(changeset)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("progress_animation_complete", params, socket) do
    {:noreply,
     assign(socket, :screenshot, %{
       drop_short_id: params["drop_short_id"],
       progress_value: 100,
       status: :completed,
       url: params["url"]
     })}
  end

  def handle_event("validate", %{"drop" => drop_params}, socket) do
    changeset =
      socket.assigns.drop
      |> Drops.change_drop(drop_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"drop" => drop_params}, socket) do
    screenshot = get_screenshot(socket.assigns.live_action, drop_params, socket.assigns.drop)
    updated_params = Map.put(drop_params, "screenshot", screenshot)

    case create_or_update_drop(socket, socket.assigns.live_action, updated_params) do
      {:ok, drop} -> handle_save_success(socket, drop)
      {:error, error} -> handle_save_error(socket, error)
    end
  end

  defp handle_save_success(socket, %{screenshot: %{status: :pending}} = drop) do
    enqueue_seo_screenshot_creation(
      drop,
      socket.assigns.drop.body,
      socket.assigns.live_action
    )

    changeset = Drops.change_drop(drop)
    {:noreply, assign_form(socket, changeset)}
  end

  defp handle_save_success(socket, drop) do
    enqueue_sitemap_generation(drop)
    {:noreply, push_navigate(socket, to: ~p"/d/#{drop.short_id}")}
  end

  defp handle_save_error(socket, %Ecto.Changeset{} = changeset) do
    {:noreply, assign_form(socket, changeset)}
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

  defp get_screenshot(:edit, drop_params, drop) do
    case CodeBlockHelper.compare_code_blocks(drop.body, drop_params["body"]) do
      :ok ->
        %{
          internal_url: nil,
          meta_url: nil,
          status: :pending
        }

      {:cancel, "No code block found"} ->
        %{
          internal_url: nil,
          meta_url: nil,
          status: :skipped
        }

      {:cancel, "Code block unchanged"} ->
        %{
          internal_url: drop.screenshot.internal_url,
          meta_url: drop.screenshot.meta_url,
          status: :completed
        }

      {:cancel, _other_reason} ->
        %{
          internal_url: nil,
          meta_url: nil,
          status: :skipped
        }
    end
  end

  defp get_screenshot(:new, drop_params, _old_drop) do
    if CodeBlockHelper.has_code_block?(drop_params["body"]) do
      %{
        internal_url: nil,
        meta_url: nil,
        status: :pending
      }
    else
      %{
        internal_url: nil,
        meta_url: nil,
        status: :skipped
      }
    end
  end

  defp enqueue_seo_screenshot_creation(drop, old_body, action) do
    Drops.broadcast_drop_screenshot_started(drop)

    %{"drop_id" => drop.id, "old_body" => old_body, "action" => action}
    |> ScreenshotGeneratorWorker.new()
    |> Oban.insert()
  end

  defp enqueue_sitemap_generation(drop) do
    %{"drop_id" => drop.id}
    |> SitemapGeneratorWorker.new()
    |> Oban.insert()
  end
end
