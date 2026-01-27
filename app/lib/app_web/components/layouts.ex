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
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
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
    <div class="flex min-h-screen">
      <aside class="w-64 bg-base-200 border-r border-base-300">
        <div class="p-4">
          <a
            href={~p"/dashboard/#{@current_scope.account.slug}"}
            class="flex items-center gap-2 text-lg font-semibold"
          >
            <.icon name="hero-squares-2x2" class="size-6" /> Dashboard
          </a>
        </div>

        <div :if={@current_scope && @current_scope.account} class="px-4 pb-4">
          <.account_switcher current_scope={@current_scope} />
        </div>

        <nav class="menu p-4">
          <ul>
            <li>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}"}
                class="flex items-center gap-2"
              >
                <.icon name="hero-building-office" class="size-5" /> Account
              </.link>
            </li>
            <li>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys"}
                class="flex items-center gap-2"
              >
                <.icon name="hero-key" class="size-5" /> API Keys
              </.link>
            </li>
          </ul>
        </nav>
      </aside>

      <div class="flex-1 flex flex-col">
        <header class="navbar px-4 sm:px-6 lg:px-8 bg-base-100 border-b border-base-300">
          <div class="flex-1">
            <span :if={@page_title} class="text-lg font-semibold">{@page_title}</span>
          </div>
          <div class="flex-none">
            <ul class="flex flex-column px-1 space-x-4 items-center">
              <li>
                <.theme_toggle />
              </li>
              <li :if={@current_scope}>
                <span class="text-sm text-base-content/70">{@current_scope.user.email}</span>
              </li>
              <li>
                <a href={~p"/"} class="btn btn-ghost btn-sm">
                  Exit Dashboard
                </a>
              </li>
            </ul>
          </div>
        </header>

        <main class="flex-1 p-4 sm:p-6 lg:p-8">
          <div class="mx-auto max-w-6xl">
            {render_slot(@inner_block)}
          </div>
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
        class="btn btn-ghost w-full justify-between text-left h-auto py-2"
      >
        <div class="flex flex-col items-start overflow-hidden">
          <span class="font-medium truncate max-w-full">{@current_scope.account.name}</span>
          <span class={[
            "badge badge-xs mt-1",
            @current_scope.account_user.role == :owner && "badge-primary",
            @current_scope.account_user.role == :admin && "badge-secondary",
            @current_scope.account_user.role == :member && "badge-ghost"
          ]}>
            {@current_scope.account_user.role}
          </span>
        </div>
        <.icon name="hero-chevron-down" class="size-4 shrink-0" />
      </div>
      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-box z-10 w-full p-2 shadow border border-base-300"
      >
        <%= for {account, role} <- @current_scope.accounts do %>
          <%= if account.id == @current_scope.account.id do %>
            <li class="disabled">
              <span class="flex justify-between items-center opacity-50">
                <span class="truncate">{account.name}</span>
                <.icon name="hero-check" class="size-4" />
              </span>
            </li>
          <% else %>
            <li>
              <.link
                navigate={~p"/dashboard/#{account.slug}"}
                class="flex justify-between items-center"
              >
                <span class="truncate">{account.name}</span>
                <span class={[
                  "badge badge-xs",
                  role == :owner && "badge-primary",
                  role == :admin && "badge-secondary",
                  role == :member && "badge-ghost"
                ]}>
                  {role}
                </span>
              </.link>
            </li>
          <% end %>
        <% end %>
      </ul>
    </div>
    """
  end
end
