defmodule ElixirDropsWeb.FeatureCase do
  @moduledoc """
  This module defines the base test case for feature tests using browser automation.

  You may define functions here to be used as helpers in your feature tests.
  """

  defmacro __using__(opts) do
    quote do
      use PhoenixTest.Playwright.Case, unquote(opts)

      # The default endpoint for testing
      @endpoint ElixirDropsWeb.Endpoint

      use ElixirDropsWeb, :verified_routes

      # Import conveniences for testing with connections and LiveViews
      import ElixirDrops.AccountsFixtures
      import ElixirDrops.DropsFixtures
      import ElixirDrops.FeatureHelpers
      import ElixirDrops.SearchFixtures
      import ElixirDropsWeb.ConnCase, except: [sign_in_user: 2]
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import PhoenixTest
      import Plug.Conn

      setup _tags do
        # PhoenixTest.Playwright.Case handles database checkout automatically
        # via checkout_ecto_repos/1 - no manual setup needed
        :ok
      end
    end
  end
end
