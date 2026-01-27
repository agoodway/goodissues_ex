defmodule FFWeb.Router do
  use FFWeb, :router

  import FFWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FFWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  # Base API pipeline - no auth, just JSON + OpenAPI spec injection
  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug
    plug OpenApiSpex.Plug.PutApiSpec, module: FFWeb.ApiSpec
  end

  # Authenticated API - requires valid API key
  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug CORSPlug
    plug OpenApiSpex.Plug.PutApiSpec, module: FFWeb.ApiSpec
    plug FFWeb.Plugs.ApiAuth, :require_api_auth
  end

  # Write access - requires private API key (sk_...)
  pipeline :api_write do
    plug :accepts, ["json"]
    plug CORSPlug
    plug OpenApiSpex.Plug.PutApiSpec, module: FFWeb.ApiSpec
    plug FFWeb.Plugs.ApiAuth, :require_api_auth
    plug FFWeb.Plugs.ApiAuth, :require_write_access
  end

  scope "/", FFWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # ============================================
  # Admin Routes
  # ============================================
  scope "/admin", FFWeb.Admin, as: :admin do
    pipe_through [:browser]

    live_session :admin,
      on_mount: [
        {FFWeb.UserAuth, :ensure_authenticated},
        {FFWeb.UserAuth, :ensure_admin}
      ] do
      live "/accounts", AccountLive.Index, :index
      live "/accounts/new", AccountLive.Index, :new
      live "/accounts/:id/edit", AccountLive.Index, :edit
      live "/accounts/:id", AccountLive.Show, :show

      live "/api-keys", ApiKeyLive.Index, :index
      live "/api-keys/new", ApiKeyLive.New, :new
      live "/api-keys/:id", ApiKeyLive.Show, :show
    end
  end

  # ============================================
  # OpenAPI Documentation (no auth required)
  # ============================================
  scope "/api/v1" do
    pipe_through :api

    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
    get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/openapi"
  end

  # ============================================
  # API Routes - Read (authenticated)
  # ============================================
  scope "/api/v1", FFWeb.Api.V1, as: :api_v1 do
    pipe_through :api_authenticated

    # Projects
    get "/projects", ProjectController, :index
    get "/projects/:id", ProjectController, :show
  end

  # ============================================
  # API Routes - Write (authenticated + write access)
  # ============================================
  scope "/api/v1", FFWeb.Api.V1, as: :api_v1 do
    pipe_through :api_write

    # Projects
    post "/projects", ProjectController, :create
    patch "/projects/:id", ProjectController, :update
    delete "/projects/:id", ProjectController, :delete
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:app, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FFWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    # MCP Server endpoint
    forward "/mcp", FFWeb.MCP.Plug, server: FFWeb.MCP.Server
  end

  ## Authentication routes

  scope "/", FFWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", FFWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", FFWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
