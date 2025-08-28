defmodule ElixirDropsWeb.FeatureCase do
  @moduledoc """
  This module defines the setup for feature tests using browser automation.

  Uses pure PhoenixTest.Playwright.Case exactly as documented.
  """

  use ExUnit.CaseTemplate

  using opts do
    quote do
      use ElixirDropsWeb, :verified_routes
      use PhoenixTest.Playwright.Case, unquote(opts)

      # Import conveniences for testing
      import ElixirDrops.AccountsFixtures
      import ElixirDrops.DropsFixtures
      import ElixirDrops.FeatureHelpers
      import ElixirDrops.SearchFixtures
      import ElixirDropsWeb.ConnCase, except: [sign_in_user: 2]
    end
  end

  # Let PhoenixTest.Playwright.Case handle all database setup
  # No custom setup block - pure documentation approach
end
