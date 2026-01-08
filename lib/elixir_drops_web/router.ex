defmodule ElixirDropsWeb.Router do
  use ElixirDropsWeb, :router

  import ElixirDropsWeb.UserAuth

  pipeline :browser do
    plug ElixirDropsWeb.Plugs.MarkdownInterceptor
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElixirDropsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :markdown do
    plug :accepts, ["markdown", "text"]
    plug :put_resp_content_type, "text/markdown"
  end

  # pipeline :api do
  #   plug :accepts, ["json"]
  # end

  # Markdown pipeline for .md requests only
  scope "/", ElixirDropsWeb do
    pipe_through :markdown

    get "/index.md", MarkdownController, :index
  end

  scope "/", ElixirDropsWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount:
        Enum.filter(
          [
            if(Application.compile_env(:elixir_drops, :sql_sandbox),
              do: {ElixirDropsWeb.LiveAcceptance, :default}
            ),
            {ElixirDropsWeb.UserAuth, :ensure_authenticated},
            {ElixirDropsWeb.UserAuth, :assign_current_user},
            {ElixirDropsWeb.LiveHelpers, :attach_shared_hooks},
            {ElixirDropsWeb.NavbarSearchHook, :navbar_search}
          ],
          & &1
        ) do
      live "/profile", UserDropLive.Index, :index
      live "/profile/bookmarks", UserDropLive.Index, :show_bookmarks

      live "/drops/:short_id/edit", UserDropLive.Index, :edit
      live "/drops/new", UserDropLive.Index, :new
    end
  end

  scope "/", ElixirDropsWeb do
    pipe_through :browser

    live_session :default,
      on_mount:
        Enum.filter(
          [
            if(Application.compile_env(:elixir_drops, :sql_sandbox),
              do: {ElixirDropsWeb.LiveAcceptance, :default}
            ),
            {ElixirDropsWeb.LiveHelpers, :attach_shared_hooks},
            {ElixirDropsWeb.LiveHelpers, :maybe_show_welcome_message},
            {ElixirDropsWeb.UserAuth, :assign_current_user},
            {ElixirDropsWeb.NavbarSearchHook, :navbar_search}
          ],
          & &1
        ) do
      live "/", DropLive.Index, :index
      live "/d/:short_id", DropLive.Show, :show
      get "/d/:id/code_snippet", CodeSnippetController, :index
    end
  end

  scope "/auth", ElixirDropsWeb do
    pipe_through :browser

    get "/logout", GithubAuthController, :logout

    get "/:provider", GithubAuthController, :request
    get "/:provider/callback", GithubAuthController, :callback
  end

  # Other scopes may use custom stacks.
  # scope "/api", ElixirDropsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:elixir_drops, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ElixirDropsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
      get "/auth/:user_id", ElixirDropsWeb.DevAuthController, :enable
    end
  end

  resources "/health", ElixirDropsWeb.HealthController, only: [:index]
end
