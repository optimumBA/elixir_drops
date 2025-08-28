defmodule ElixirDropsWeb.LiveAcceptance do
  @moduledoc """
  LiveView acceptance testing hook for handling Ecto SQL Sandbox.

  Ensures all LiveView processes and their spawned children can access the 
  test database connection in async tests.
  """

  import Phoenix.Component
  import Phoenix.LiveView

  require Logger

  @type socket :: Phoenix.LiveView.Socket.t()

  @spec on_mount(atom(), map(), map(), socket()) :: {:cont, socket()}
  def on_mount(:default, _params, _session, socket) do
    socket =
      assign_new(socket, :phoenix_ecto_sandbox, fn ->
        get_connect_info(socket, :user_agent)
      end)

    metadata = socket.assigns.phoenix_ecto_sandbox

    if metadata do
      setup_sandbox_access(metadata)
    end

    {:cont, socket}
  end

  defp setup_sandbox_access(metadata) do
    # Use the standard Phoenix.Ecto.SQL.Sandbox.allow/2 first
    Phoenix.Ecto.SQL.Sandbox.allow(metadata, Ecto.Adapters.SQL.Sandbox)

    # Additionally decode and set up repository access for this process
    case Phoenix.Ecto.SQL.Sandbox.decode_metadata(metadata) do
      {:ok, {repo, owner_pid}} ->
        # Ensure this LiveView process can access the database
        Ecto.Adapters.SQL.Sandbox.allow(repo, owner_pid, self())

        # Set up shared mode for this LiveView process tree
        # This allows any child processes to access the database
        Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})

      {:error, _reason} ->
        Logger.debug("Failed to decode sandbox metadata, using basic allowance")
        :ok

      _other ->
        Logger.debug("Invalid metadata format, using basic allowance")
        :ok
    end
  rescue
    DBConnection.OwnershipError ->
      # Connection already allowed - this is expected in some test scenarios
      :ok
  end
end
