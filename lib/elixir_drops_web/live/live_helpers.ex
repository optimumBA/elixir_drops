defmodule ElixirDropsWeb.LiveHelpers do
  @moduledoc """
  LiveView helpers including database sandbox support for tests.

  Based on StoryDeck's proven async testing patterns.
  """

  import Phoenix.Component
  import Phoenix.LiveView, only: [get_connect_params: 1]

  alias ElixirDropsWeb.NotificationHelpers

  @type socket :: Phoenix.LiveView.Socket.t()

  # Existing welcome message functionality
  @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
  def on_mount(:maybe_show_welcome_message, _params, _session, socket) do
    show_welcome_message =
      case get_connect_params(socket) do
        %{"show_welcome_message" => "true"} -> true
        _other -> false
      end

    {:cont, assign(socket, :show_welcome_message?, show_welcome_message)}
  end

  @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
  def on_mount(:assign_notifications, _params, _session, socket) do
    {:cont, NotificationHelpers.assign_notifications(socket)}
  end

  # Only compile sandbox support in test environment
  if Application.compile_env(:elixir_drops, :sandbox, false) do
    @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
    def on_mount(:allow_ecto_sandbox, _params, _session, socket) do
      # Get encoded metadata from process dictionary (set by FeatureCase)
      if encoded_metadata = Process.get(:phoenix_ecto_sandbox) do
        try do
          # Decode and allow this process to access the database
          metadata = Phoenix.Ecto.SQL.Sandbox.decode_metadata(encoded_metadata)
          # Correct API: Ecto.Adapters.SQL.Sandbox.allow(repo, owner_pid, allow_pid)
          # metadata contains {repo, owner_pid}, so we extract the owner and allow current process
          case metadata do
            {_repo, owner_pid} when is_pid(owner_pid) ->
              Ecto.Adapters.SQL.Sandbox.allow(ElixirDrops.Repo, owner_pid, self())

            _other ->
              :ok
          end
        rescue
          # If allow fails (e.g., already allowed), that's OK
          _error -> :ok
        end
      end

      {:cont, socket}
    end
  else
    @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
    def on_mount(:allow_ecto_sandbox, _params, _session, socket), do: {:cont, socket}
  end
end
