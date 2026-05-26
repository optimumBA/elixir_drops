defmodule ElixirDrops.WallabyAdapter do
  @moduledoc false

  alias Wallaby.Browser
  alias Wallaby.Session

  @type capabilities :: keyword()
  @type screenshot_path :: binary()
  @type session :: Session.t()

  @callback start_session(capabilities()) :: {:ok, session()} | {:error, any()}
  @callback end_session(session()) :: :ok | {:error, any()}
  @callback visit(session(), binary()) :: session()
  @callback take_screenshot(session()) :: session()

  @spec start_session(capabilities()) :: {:ok, session()} | {:error, any()}
  def start_session(capabilities), do: impl().start_session(capabilities)

  @spec end_session(session()) :: :ok | {:error, any()}
  def end_session(session), do: impl().end_session(session)

  @spec visit(session(), binary()) :: session()
  def visit(session, url), do: impl().visit(session, url)

  @spec take_screenshot(session()) :: session()
  def take_screenshot(session), do: impl().take_screenshot(session)

  defp impl, do: Application.get_env(:elixir_drops, :wallaby_adapter, __MODULE__.Live)

  defmodule Live do
    @moduledoc false

    @behaviour ElixirDrops.WallabyAdapter

    @impl ElixirDrops.WallabyAdapter
    def start_session(capabilities), do: Wallaby.start_session(capabilities)

    @impl ElixirDrops.WallabyAdapter
    def end_session(session), do: Wallaby.end_session(session)

    @impl ElixirDrops.WallabyAdapter
    def visit(session, url), do: Browser.visit(session, url)

    @impl ElixirDrops.WallabyAdapter
    def take_screenshot(session), do: Browser.take_screenshot(session)
  end
end
