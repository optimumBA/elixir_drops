defmodule ElixirDropsWeb.UserDropLive.FormComponent do
  @moduledoc false

  use ElixirDropsWeb, :live_component

  import Phoenix.HTML.Form

  alias ElixirDrops.Drops
  alias ElixirDrops.Workers.ScreenshotGeneratorWorker
  alias ElixirDropsWeb.CodeBlockHelper
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
    updated_params = add_or_retain_screenshot_status(:edit, drop_params, socket.assigns.drop)

    case Drops.update_drop(
           socket.assigns.drop,
           socket.assigns.current_user,
           updated_params
         ) do
      {:ok, drop} ->
        {:ok, drop}

      error ->
        error
    end
  end

  defp create_or_update_drop(socket, :new, drop_params) do
    case Drops.create_drop(
           socket.assigns.drop,
           socket.assigns.current_user,
           drop_params
         ) do
      {:ok, drop} ->
        needs_screenshot? = CodeBlockHelper.has_code_block?(drop_params["body"])

        if needs_screenshot? do
          {:ok, drop}
        else
          Drops.update_drop_screenshot(drop, %{screenshot: %{status: :skipped, url: nil}})
        end

      error ->
        error
    end
  end

  defp enqueue_seo_screenshot_creation(drop, old_body, action) do
    Drops.update_drop_screenshot(drop, %{screenshot: %{status: :pending, url: nil}})

    send(self(), :screenshot_generation_started)

    %{"drop_id" => drop.id, "old_body" => old_body, "action" => action}
    |> ScreenshotGeneratorWorker.new()
    |> Oban.insert()
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp maybe_enqueue_screenshot_generation(socket, drop) do
    if drop.screenshot && drop.screenshot.status in [:skipped, :completed] do
      socket = push_navigate(socket, to: ~p"/profile")
      {:noreply, socket}
    else
      case socket.assigns do
        %{live_action: :edit} ->
          enqueue_seo_screenshot_creation(drop, socket.assigns.drop.body, :edit)

          {:noreply, socket}

        %{live_action: :new} ->
          enqueue_seo_screenshot_creation(drop, nil, :new)

          {:noreply, socket}
      end
    end
  end

  defp add_or_retain_screenshot_status(:edit, drop_params, old_drop) do
    screenshot =
      case CodeBlockHelper.compare_code_blocks(old_drop.body, drop_params["body"]) do
        :ok ->
          %{
            "status" => :pending,
            "url" => nil
          }

        {:cancel, "No code block found"} ->
          %{
            "status" => :skipped,
            "url" => nil
          }

        {:cancel, "Code block unchanged"} ->
          %{
            "status" => :completed,
            "url" => old_drop.screenshot.url
          }

        {:cancel, _other_reason} ->
          %{
            "status" => :skipped,
            "url" => nil
          }
      end

    Map.put(drop_params, "screenshot", screenshot)
  end
end
