defmodule GIWeb.Router do
  use GIWeb, :router

  import GIWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GIWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  # Base API pipeline - no auth, just JSON + OpenAPI spec injection
  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug
    plug OpenApiSpex.Plug.PutApiSpec, module: GIWeb.ApiSpec
  end

  # Authenticated API - requires valid API key
  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug CORSPlug
    plug OpenApiSpex.Plug.PutApiSpec, module: GIWeb.ApiSpec
    plug GIWeb.Plugs.ApiAuth, :require_api_auth
  end

  # Write access - requires private API key (sk_...)
  pipeline :api_write do
    plug :accepts, ["json"]
    plug CORSPlug
    plug OpenApiSpex.Plug.PutApiSpec, module: GIWeb.ApiSpec
    plug GIWeb.Plugs.ApiAuth, :require_api_auth
    plug GIWeb.Plugs.ApiAuth, :require_write_access
  end

  scope "/", GIWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # ============================================
  # Dashboard Routes (account-scoped by slug in URL)
  # ============================================

  # Redirect /dashboard to user's first account
  scope "/dashboard", GIWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/", DashboardController, :index
  end

  # Account-scoped dashboard routes
  scope "/dashboard/:account_slug", GIWeb.Dashboard, as: :dashboard do
    pipe_through [:browser]

    live_session :dashboard,
      on_mount: [
        {GIWeb.UserAuth, :ensure_authenticated},
        {GIWeb.UserAuth, :load_account_from_slug}
      ] do
      live "/", AccountLive.Index, :index
      live "/settings", AccountLive.Index, :edit

      live "/api-keys", ApiKeyLive.Index, :index
      live "/api-keys/new", ApiKeyLive.New, :new
      live "/api-keys/:id", ApiKeyLive.Show, :show
      live "/api-keys/:id/edit", ApiKeyLive.Edit, :edit

      live "/issues", IssueLive.Index, :index
      live "/issues/new", IssueLive.New, :new
      live "/issues/:id", IssueLive.Show, :show
      live "/issues/:id/edit", IssueLive.Show, :edit

      live "/subscriptions", SubscriptionLive.Index, :index
      live "/subscriptions/new", SubscriptionLive.New, :new
      live "/subscriptions/:id", SubscriptionLive.Show, :show

      live "/projects", ProjectLive.Index, :index
      live "/projects/new", ProjectLive.New, :new
      live "/projects/:id", ProjectLive.Show, :show
      live "/projects/:id/edit", ProjectLive.Show, :edit

      live "/projects/:project_id/checks", CheckLive.Index, :index
      live "/projects/:project_id/checks/new", CheckLive.New, :new
      live "/projects/:project_id/checks/:id", CheckLive.Show, :show
      live "/projects/:project_id/checks/:id/edit", CheckLive.Show, :edit
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

  # Authenticated API with rate limiting for public ping endpoints
  pipeline :api_rate_limited do
    plug :accepts, ["json"]
    plug CORSPlug
    plug OpenApiSpex.Plug.PutApiSpec, module: GIWeb.ApiSpec
    plug GIWeb.Plugs.RateLimiter, max_requests: 60, window_ms: 60_000
  end

  # ============================================
  # API Routes - Public (token-authenticated, no Bearer)
  # ============================================
  scope "/api/v1", GIWeb.Api.V1, as: :api_v1 do
    pipe_through :api_rate_limited

    post "/projects/:project_id/heartbeats/:heartbeat_token/ping", HeartbeatPingController, :ping

    post "/projects/:project_id/heartbeats/:heartbeat_token/ping/start",
         HeartbeatPingController,
         :start

    post "/projects/:project_id/heartbeats/:heartbeat_token/ping/fail",
         HeartbeatPingController,
         :fail
  end

  # ============================================
  # API Routes - Read (authenticated)
  # ============================================
  scope "/api/v1", GIWeb.Api.V1, as: :api_v1 do
    pipe_through :api_authenticated

    # Projects
    get "/projects", ProjectController, :index
    get "/projects/:id", ProjectController, :show

    # Issues
    get "/issues", IssueController, :index
    get "/issues/:id", IssueController, :show

    # Errors
    get "/errors", ErrorController, :index
    get "/errors/search", ErrorController, :search
    get "/errors/:id", ErrorController, :show

    # Checks (nested under projects)
    get "/projects/:project_id/checks", CheckController, :index
    get "/projects/:project_id/checks/:check_id", CheckController, :show
    get "/projects/:project_id/checks/:check_id/results", CheckResultController, :index

    # Heartbeats (nested under projects)
    get "/projects/:project_id/heartbeats", HeartbeatController, :index
    get "/projects/:project_id/heartbeats/:heartbeat_id", HeartbeatController, :show

    get "/projects/:project_id/heartbeats/:heartbeat_id/pings",
        HeartbeatPingHistoryController,
        :index
  end

  # ============================================
  # API Routes - Write (authenticated + write access)
  # ============================================
  scope "/api/v1", GIWeb.Api.V1, as: :api_v1 do
    pipe_through :api_write

    # Projects
    post "/projects", ProjectController, :create
    patch "/projects/:id", ProjectController, :update
    delete "/projects/:id", ProjectController, :delete

    # Issues
    post "/issues", IssueController, :create
    patch "/issues/:id", IssueController, :update
    delete "/issues/:id", IssueController, :delete

    # Errors
    post "/errors", ErrorController, :create
    patch "/errors/:id", ErrorController, :update

    # Events (telemetry)
    post "/events/batch", EventController, :create_batch

    # Checks (nested under projects)
    post "/projects/:project_id/checks", CheckController, :create
    patch "/projects/:project_id/checks/:check_id", CheckController, :update
    delete "/projects/:project_id/checks/:check_id", CheckController, :delete

    # Heartbeats (nested under projects)
    post "/projects/:project_id/heartbeats", HeartbeatController, :create
    patch "/projects/:project_id/heartbeats/:heartbeat_id", HeartbeatController, :update
    delete "/projects/:project_id/heartbeats/:heartbeat_id", HeartbeatController, :delete
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:good_issues, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GIWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    # MCP Server endpoint
    forward "/mcp", GIWeb.MCP.Plug, server: GIWeb.MCP.Server
  end

  ## Authentication routes

  scope "/", GIWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", GIWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", GIWeb do
    pipe_through [:browser]

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
