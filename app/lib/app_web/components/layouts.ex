defmodule FFWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FFWeb, :html

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
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
          </li>
          <li>
            <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
          </li>
          <li>
            <.theme_toggle />
          </li>
          <li>
            <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
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
    <div class="flex items-center gap-0.5 p-0.5 rounded-lg bg-base-300/50">
      <button
        class="p-1.5 rounded-md hover:bg-base-200 text-muted hover:text-base-content transition-colors [[data-theme=system]_&]:bg-base-200 [[data-theme=system]_&]:text-base-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="System theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>

      <button
        class="p-1.5 rounded-md hover:bg-base-200 text-muted hover:text-base-content transition-colors [[data-theme=light]_&]:bg-base-200 [[data-theme=light]_&]:text-base-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-4" />
      </button>

      <button
        class="p-1.5 rounded-md hover:bg-base-200 text-muted hover:text-base-content transition-colors [[data-theme=dark]_&]:bg-base-200 [[data-theme=dark]_&]:text-base-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4" />
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

  slot :inner_block, required: true

  def dashboard(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-base-100">
      <%!-- Linear-style sidebar --%>
      <aside class="sidebar w-56 flex flex-col">
        <%!-- Logo/Brand area --%>
        <div class="p-3 flex items-center gap-2">
          <div class="size-7 rounded-lg bg-gradient-to-br from-primary/80 to-primary flex items-center justify-center">
            <.icon name="hero-bolt" class="size-4 text-primary-content" />
          </div>
          <span class="font-semibold text-sm text-base-content">Fruitfly</span>
        </div>

        <%!-- Search --%>
        <div class="px-3 pb-2">
          <div class="relative">
            <.icon name="hero-magnifying-glass" class="size-4 absolute left-2.5 top-1/2 -translate-y-1/2 icon-muted" />
            <input
              type="text"
              placeholder="Search..."
              class="input-search w-full pl-8 py-1.5 text-sm"
            />
          </div>
        </div>

        <%!-- Main navigation --%>
        <nav class="flex-1 px-2 py-2 space-y-0.5">
          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}"}
            class="nav-item"
          >
            <.icon name="hero-home" class="size-4" />
            <span>Home</span>
          </.link>

          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}"}
            class="nav-item"
          >
            <.icon name="hero-inbox" class="size-4" />
            <span>Inbox</span>
          </.link>

          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}"}
            class="nav-item"
          >
            <.icon name="hero-clipboard-document-list" class="size-4" />
            <span>My Issues</span>
          </.link>

          <%!-- Workspace section --%>
          <div class="nav-section-header mt-4">Workspace</div>

          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}"}
            class="nav-item"
          >
            <.icon name="hero-folder" class="size-4" />
            <span>Projects</span>
          </.link>

          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}"}
            class="nav-item"
          >
            <.icon name="hero-eye" class="size-4" />
            <span>Views</span>
          </.link>

          <%!-- Account section --%>
          <div class="nav-section-header mt-4">Account</div>

          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}"}
            class="nav-item"
          >
            <.icon name="hero-building-office" class="size-4" />
            <span>Settings</span>
          </.link>

          <.link
            navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys"}
            class="nav-item active"
          >
            <.icon name="hero-key" class="size-4" />
            <span>API Keys</span>
          </.link>
        </nav>

        <%!-- Account switcher at bottom --%>
        <div :if={@current_scope && @current_scope.account} class="p-2 border-t border-base-300/50">
          <.account_switcher current_scope={@current_scope} />
        </div>
      </aside>

      <%!-- Main content area --%>
      <div class="flex-1 flex flex-col min-w-0">
        <%!-- Top header bar --%>
        <header class="h-12 px-4 flex items-center justify-between border-b border-base-300/50 bg-base-100">
          <div class="flex items-center gap-3">
            <button class="p-1.5 rounded hover:bg-base-200 text-muted">
              <.icon name="hero-arrow-left" class="size-4" />
            </button>
            <button class="p-1.5 rounded hover:bg-base-200 text-muted">
              <.icon name="hero-arrow-right" class="size-4" />
            </button>
          </div>

          <div class="flex items-center gap-2">
            <.theme_toggle />
          </div>
        </header>

        <%!-- Page content --%>
        <main class="flex-1 overflow-auto">
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
        class="w-full flex items-center gap-2 px-2 py-1.5 rounded-md hover:bg-base-300/30 cursor-pointer transition-colors"
      >
        <div class="size-6 rounded bg-gradient-to-br from-accent/60 to-accent flex items-center justify-center text-xs font-medium text-accent-content">
          {String.first(@current_scope.account.name)}
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-medium truncate">{@current_scope.account.name}</div>
          <div class="text-xs text-muted">{@current_scope.account_user.role}</div>
        </div>
        <.icon name="hero-chevron-up-down" class="size-4 text-muted shrink-0" />
      </div>
      <ul
        tabindex="0"
        class="dropdown-content z-20 w-full mt-1 py-1 rounded-lg bg-base-200 border border-base-300 shadow-lg"
      >
        <%= for {account, role} <- @current_scope.accounts do %>
          <%= if account.id == @current_scope.account.id do %>
            <li class="px-2 py-1.5 flex items-center gap-2 text-sm opacity-50">
              <div class="size-5 rounded bg-accent/40 flex items-center justify-center text-xs font-medium">
                {String.first(account.name)}
              </div>
              <span class="flex-1 truncate">{account.name}</span>
              <.icon name="hero-check" class="size-4" />
            </li>
          <% else %>
            <li>
              <.link
                navigate={~p"/dashboard/#{account.slug}"}
                class="px-2 py-1.5 flex items-center gap-2 text-sm hover:bg-base-300/50 rounded"
              >
                <div class="size-5 rounded bg-neutral/50 flex items-center justify-center text-xs font-medium">
                  {String.first(account.name)}
                </div>
                <span class="flex-1 truncate">{account.name}</span>
                <span class="text-xs text-muted">{role}</span>
              </.link>
            </li>
          <% end %>
        <% end %>
      </ul>
    </div>
    """
  end
end
