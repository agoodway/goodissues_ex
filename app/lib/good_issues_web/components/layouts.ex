defmodule GIWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.

  Design System: Industrial Terminal Aesthetic
  - Sharp corners, precise typography
  - JetBrains Mono for monospace elements
  - DM Sans for body text
  - High contrast with green accent color
  """
  use GIWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8 border-b border-base-300">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-3">
          <div class="size-8 rounded bg-primary/20 border border-primary/30 flex items-center justify-center">
            <span class="font-mono text-primary font-bold text-sm">GI</span>
          </div>
          <span class="font-mono text-xs text-muted">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <a href="https://phoenixframework.org/" class="btn btn-ghost font-mono text-xs">
              Website
            </a>
          </li>
          <li>
            <a
              href="https://github.com/phoenixframework/phoenix"
              class="btn btn-ghost font-mono text-xs"
            >
              GitHub
            </a>
          </li>
          <li>
            <.theme_toggle />
          </li>
          <li>
            <a href="https://hexdocs.pm/phoenix/overview.html" class="btn-action">
              Get Started <span aria-hidden="true">&rarr;</span>
            </a>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="flex items-center gap-px p-px rounded bg-base-300/50 border border-base-300">
      <button
        class="p-1 rounded-sm hover:bg-base-200 text-muted hover:text-base-content transition-colors [[data-theme=system]_&]:bg-base-200 [[data-theme=system]_&]:text-primary"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="System theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-3" />
      </button>

      <button
        class="p-1 rounded-sm hover:bg-base-200 text-muted hover:text-base-content transition-colors [[data-theme=light]_&]:bg-base-200 [[data-theme=light]_&]:text-primary"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-3" />
      </button>

      <button
        class="p-1 rounded-sm hover:bg-base-200 text-muted hover:text-base-content transition-colors [[data-theme=dark]_&]:bg-base-200 [[data-theme=dark]_&]:text-primary"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-3" />
      </button>
    </div>
    """
  end

  @doc """
  Renders the dashboard layout.

  This layout is used for account-scoped dashboard pages and includes a sidebar navigation.

  ## Examples

      <Layouts.dashboard flash={@flash} current_scope={@current_scope}>
        <h1>Dashboard Content</h1>
      </Layouts.dashboard>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :page_title, :string, default: nil, doc: "the page title"

  attr :active_nav, :atom,
    default: nil,
    doc: "the currently active navigation item (:issues, :projects, :settings, :api_keys)"

  slot :inner_block, required: true

  def dashboard(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-base-100" id="dashboard-layout" phx-hook="MobileSidebar">
      <%!-- Mobile sidebar backdrop --%>
      <div
        id="sidebar-backdrop"
        class="fixed inset-0 bg-black/50 z-40 lg:hidden hidden"
        phx-click={JS.dispatch("toggle-sidebar")}
      >
      </div>

      <%!-- Industrial Terminal Sidebar --%>
      <aside
        id="sidebar"
        class="sidebar w-72 flex flex-col fixed inset-y-0 left-0 z-50 lg:static lg:w-60 transition-transform duration-200 ease-out"
      >
        <%!-- Brand area with terminal aesthetic --%>
        <div class="p-4 flex items-center justify-between border-b border-base-300/30">
          <div class="flex items-center gap-3">
            <div class="size-8 rounded-sm bg-primary/15 border border-primary/25 flex items-center justify-center glow-primary">
              <span class="font-mono text-primary font-bold text-sm">GI</span>
            </div>
            <div class="flex flex-col">
              <span class="font-semibold text-sm text-base-content tracking-tight">GoodIssues</span>
              <span class="font-mono text-[10px] text-muted uppercase tracking-wider">
                Bug Tracker
              </span>
            </div>
          </div>
          <%!-- Close button for mobile --%>
          <button
            class="lg:hidden p-2 -mr-2 rounded-sm hover:bg-base-200 text-muted"
            phx-click={JS.dispatch("toggle-sidebar")}
            aria-label="Close menu"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <%!-- Terminal-style search --%>
        <div class="px-3 py-3">
          <div class="relative">
            <span class="absolute left-2.5 top-1/2 -translate-y-1/2 font-mono text-primary text-xs">
              &gt;
            </span>
            <input
              type="text"
              placeholder="search..."
              class="input-search w-full pl-7 py-2 text-sm font-mono"
            />
          </div>
        </div>

        <%!-- Main navigation --%>
        <nav class="flex-1 px-2 py-1 space-y-1 overflow-y-auto">
          <%!-- Workspace section --%>
          <div class="nav-section-header">// Workspace</div>

          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}/issues"}
            class={["nav-item", @active_nav == :issues && "active"]}
          >
            <.icon name="hero-bug-ant" class="size-5" />
            <span>Issues</span>
          </.link>

          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}/projects"}
            class={["nav-item", @active_nav == :projects && "active"]}
          >
            <.icon name="hero-folder" class="size-5" />
            <span>Projects</span>
          </.link>

          <%!-- Account section --%>
          <div class="nav-section-header mt-5">// Account</div>

          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}"}
            class={["nav-item", @active_nav == :settings && "active"]}
          >
            <.icon name="hero-cog-6-tooth" class="size-5" />
            <span>Settings</span>
          </.link>

          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys"}
            class={["nav-item", @active_nav == :api_keys && "active"]}
          >
            <.icon name="hero-key" class="size-5" />
            <span>API Keys</span>
          </.link>

          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}/subscriptions"}
            class={["nav-item", @active_nav == :subscriptions && "active"]}
          >
            <.icon name="hero-bell" class="size-5" />
            <span>Subscriptions</span>
          </.link>
        </nav>

        <%!-- Account switcher at bottom --%>
        <div :if={@current_scope && @current_scope.account} class="p-3 border-t border-base-300/30">
          <.account_switcher current_scope={@current_scope} />
        </div>
      </aside>

      <%!-- Main content area --%>
      <div class="flex-1 flex flex-col min-w-0 w-full">
        <%!-- Top header bar --%>
        <header class="h-14 lg:h-11 px-4 flex items-center justify-between border-b border-base-300/50 bg-base-100 sticky top-0 z-30">
          <div class="flex items-center gap-3">
            <%!-- Mobile menu button --%>
            <button
              class="lg:hidden p-2 -ml-2 rounded-sm hover:bg-base-200 text-base-content"
              phx-click={JS.dispatch("toggle-sidebar")}
              aria-label="Open menu"
            >
              <.icon name="hero-bars-3" class="size-6" />
            </button>
            <span class="font-mono text-xs text-muted">{@page_title || "Dashboard"}</span>
          </div>

          <div class="flex items-center gap-3">
            <span class="font-mono text-[10px] text-muted hidden sm:block">
              {Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M")} UTC
            </span>
            <.theme_toggle />
          </div>
        </header>

        <%!-- Page content --%>
        <main class="flex-1 overflow-auto bg-grid p-4 lg:p-6">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders an account switcher dropdown.

  Shows the current account name with a role badge and allows switching
  to other accounts the user belongs to.
  """
  attr :current_scope, :map, required: true

  def account_switcher(assigns) do
    ~H"""
    <div class="dropdown w-full">
      <div
        tabindex="0"
        role="button"
        class="w-full flex items-center gap-2.5 px-2.5 py-2 rounded-sm hover:bg-base-300/30 cursor-pointer transition-colors border border-transparent hover:border-base-300/50"
      >
        <div class="size-7 rounded-sm bg-primary/15 border border-primary/25 flex items-center justify-center font-mono text-xs font-bold text-primary">
          {String.first(@current_scope.account.name) |> String.upcase()}
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-medium truncate">{@current_scope.account.name}</div>
          <div class="font-mono text-[10px] text-muted uppercase tracking-wider">
            {@current_scope.account_user.role}
          </div>
        </div>
        <.icon name="hero-chevron-up-down" class="size-4 text-muted shrink-0" />
      </div>
      <ul
        tabindex="0"
        class="dropdown-content z-20 w-full mt-1 py-1 rounded-sm bg-base-200 border border-base-300 shadow-lg"
      >
        <%= for {account, role} <- @current_scope.accounts do %>
          <%= if account.id == @current_scope.account.id do %>
            <li class="px-2.5 py-2 flex items-center gap-2.5 text-sm opacity-50">
              <div class="size-6 rounded-sm bg-primary/10 border border-primary/20 flex items-center justify-center font-mono text-xs font-bold text-primary/60">
                {String.first(account.name) |> String.upcase()}
              </div>
              <span class="flex-1 truncate">{account.name}</span>
              <.icon name="hero-check" class="size-4 text-primary" />
            </li>
          <% else %>
            <li>
              <.link
                navigate={~p"/dashboard/#{account.slug}"}
                class="px-2.5 py-2 flex items-center gap-2.5 text-sm hover:bg-base-300/50 rounded-sm"
              >
                <div class="size-6 rounded-sm bg-neutral/30 border border-neutral/40 flex items-center justify-center font-mono text-xs font-medium">
                  {String.first(account.name) |> String.upcase()}
                </div>
                <span class="flex-1 truncate">{account.name}</span>
                <span class="font-mono text-[10px] text-muted uppercase">{role}</span>
              </.link>
            </li>
          <% end %>
        <% end %>
      </ul>
    </div>
    """
  end
end
