defmodule FFWeb.Dashboard.ApiKeyLive.Index do
  @moduledoc """
  Dashboard view for listing API keys scoped to the current account.

  Shows all API keys belonging to the current account, with filtering
  and pagination. Users with owner/admin role can revoke keys.
  """
  use FFWeb, :live_view

  alias FF.Accounts
  alias FF.Accounts.Scope

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :can_manage, Scope.can_manage_account?(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    account = socket.assigns.current_scope.account
    page = String.to_integer(params["page"] || "1")
    search = params["search"] || ""
    status = params["status"] || ""
    type = params["type"] || ""

    result =
      Accounts.list_account_api_keys(account,
        page: page,
        search: search,
        status: status,
        type: type
      )

    socket
    |> assign(:page_title, "API Keys")
    |> assign(:api_keys, result.api_keys)
    |> assign(:page, result.page)
    |> assign(:total_pages, result.total_pages)
    |> assign(:total, result.total)
    |> assign(:search, search)
    |> assign(:status_filter, status)
    |> assign(:type_filter, type)
  end

  defp pagination_path(account_slug, search, status, type, page) do
    params =
      %{search: search, status: status, type: type, page: page}
      |> Enum.reject(fn {_k, v} -> v == "" or v == 1 end)

    ~p"/dashboard/#{account_slug}/api-keys?#{params}"
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    account_slug = socket.assigns.current_scope.account.slug

    {:noreply,
     push_patch(socket,
       to:
         pagination_path(
           account_slug,
           search,
           socket.assigns.status_filter,
           socket.assigns.type_filter,
           1
         )
     )}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    account_slug = socket.assigns.current_scope.account.slug

    {:noreply,
     push_patch(socket,
       to:
         pagination_path(
           account_slug,
           socket.assigns.search,
           status,
           socket.assigns.type_filter,
           1
         )
     )}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    account_slug = socket.assigns.current_scope.account.slug

    {:noreply,
     push_patch(socket,
       to:
         pagination_path(
           account_slug,
           socket.assigns.search,
           socket.assigns.status_filter,
           type,
           1
         )
     )}
  end

  @impl true
  def handle_event("revoke", %{"id" => id}, socket) do
    account = socket.assigns.current_scope.account
    account_user = socket.assigns.current_scope.account_user

    case Accounts.revoke_account_api_key(account, account_user, id) do
      {:ok, _api_key} ->
        result =
          Accounts.list_account_api_keys(account,
            page: socket.assigns.page,
            search: socket.assigns.search,
            status: socket.assigns.status_filter,
            type: socket.assigns.type_filter
          )

        {:noreply,
         socket
         |> put_flash(:info, "API key revoked successfully.")
         |> assign(:api_keys, result.api_keys)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "API key not found.")}

      {:error, :not_authorized} ->
        {:noreply, put_flash(socket, :error, "You don't have permission to revoke API keys.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to revoke API key.")}
    end
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <FFWeb.Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      active_nav={:api_keys}
    >
      <div class="h-full flex flex-col">
        <%!-- Page header with terminal aesthetic --%>
        <div class="px-6 py-5 border-b border-base-300/50 bg-base-100">
          <div class="flex items-center justify-between mb-5">
            <div class="flex items-center gap-4">
              <div class="size-10 rounded-sm bg-primary/10 border border-primary/20 flex items-center justify-center">
                <.icon name="hero-key" class="size-5 text-primary" />
              </div>
              <div>
                <h1 class="text-lg font-semibold text-base-content">API Keys</h1>
                <div class="font-mono text-xs text-muted mt-0.5">
                  {@total} keys • {@current_scope.account.name}
                </div>
              </div>
            </div>
            <.link
              :if={@can_manage}
              navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/new"}
              class="btn-action flex items-center gap-2"
            >
              <.icon name="hero-plus" class="size-4" />
              <span>New Key</span>
            </.link>
          </div>

          <%!-- Terminal-style filters row --%>
          <div class="flex items-center gap-3">
            <form phx-change="search" phx-submit="search" class="flex-1 max-w-sm">
              <div class="relative">
                <span class="absolute left-3 top-1/2 -translate-y-1/2 font-mono text-primary text-xs">
                  $
                </span>
                <input
                  type="text"
                  name="search"
                  value={@search}
                  placeholder="grep -i ..."
                  phx-debounce="300"
                  class="input-search w-full pl-7 py-2 text-sm font-mono"
                />
              </div>
            </form>

            <form phx-change="filter_status">
              <select name="status" class="select-minimal font-mono">
                <option value="" selected={@status_filter == ""}>--status=*</option>
                <option value="active" selected={@status_filter == "active"}>--status=active</option>
                <option value="revoked" selected={@status_filter == "revoked"}>
                  --status=revoked
                </option>
              </select>
            </form>

            <form phx-change="filter_type">
              <select name="type" class="select-minimal font-mono">
                <option value="" selected={@type_filter == ""}>--type=*</option>
                <option value="public" selected={@type_filter == "public"}>--type=pk_*</option>
                <option value="private" selected={@type_filter == "private"}>--type=sk_*</option>
              </select>
            </form>
          </div>
        </div>

        <%!-- List content --%>
        <div class="flex-1 overflow-auto px-2 sm:px-0">
          <%!-- Table header (hidden on mobile) --%>
          <div :if={@total > 0} class="group-header sticky top-0 z-10 hidden sm:flex">
            <div class="flex items-center gap-2 flex-1">
              <span>// KEYS</span>
              <span class="opacity-60">
                [{length(Enum.filter(@api_keys, &(&1.status == :active)))} active]
              </span>
            </div>
            <div class="hidden sm:block w-40 text-right">OWNER</div>
            <div class="w-20 text-right">TYPE</div>
            <div class="hidden lg:block w-32 text-right">CREATED</div>
            <div class="w-20"></div>
          </div>

          <%!-- API Keys list with staggered animation --%>
          <div id="api-keys-list" class="animate-stagger space-y-2 sm:space-y-0">
            <%= for api_key <- @api_keys do %>
              <%!-- Mobile card layout --%>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/#{api_key.id}"}
                class="sm:hidden block p-4 rounded-lg border border-base-300/50 bg-base-100"
                id={"api-key-mobile-#{api_key.id}"}
              >
                <div class="flex items-start justify-between gap-3 mb-3">
                  <div class="flex items-center gap-3 flex-1 min-w-0">
                    <div class={[
                      "size-2.5 rounded-full shrink-0",
                      api_key.status == :active && "bg-success shadow-[0_0_8px] shadow-success/50",
                      api_key.status == :revoked && "bg-error/40"
                    ]}>
                    </div>
                    <div class="flex-1 min-w-0">
                      <span class={[
                        "font-medium block",
                        api_key.status == :revoked && "line-through opacity-40"
                      ]}>
                        {api_key.name}
                      </span>
                      <span class="text-xs text-muted font-mono mt-1 block">
                        {if api_key.type == :private, do: "sk_***", else: "pk_***"}
                      </span>
                    </div>
                  </div>
                  <%= if @can_manage && api_key.status == :active do %>
                    <button
                      phx-click="revoke"
                      phx-value-id={api_key.id}
                      data-confirm="Are you sure you want to revoke this API key? This action cannot be undone."
                      class="p-2 rounded-sm hover:bg-error/15 text-error/60 hover:text-error transition-colors"
                      onclick="event.preventDefault(); event.stopPropagation();"
                    >
                      <.icon name="hero-trash" class="size-4" />
                    </button>
                  <% end %>
                </div>
                <div class="flex items-center justify-between">
                  <span class={[
                    "status-badge",
                    api_key.type == :private && "status-badge-pending",
                    api_key.type == :public && "status-badge-active"
                  ]}>
                    {if api_key.type == :private, do: "WRITE", else: "READ"}
                  </span>
                  <span class="text-xs text-muted font-mono">
                    {format_datetime(api_key.inserted_at)}
                  </span>
                </div>
              </.link>

              <%!-- Desktop row layout --%>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/#{api_key.id}"}
                class="data-row group cursor-pointer hidden sm:flex"
                id={"api-key-#{api_key.id}"}
              >
                <%!-- Status indicator --%>
                <div class="w-8 flex justify-center">
                  <div class={[
                    "size-2.5 rounded-full",
                    api_key.status == :active && "bg-success shadow-[0_0_8px] shadow-success/50",
                    api_key.status == :revoked && "bg-error/40"
                  ]}>
                  </div>
                </div>

                <%!-- Key name with mono font --%>
                <div class="flex-1 min-w-0 flex items-center gap-3">
                  <span class={[
                    "font-medium",
                    api_key.status == :revoked && "line-through opacity-40"
                  ]}>
                    {api_key.name}
                  </span>
                  <span class={[
                    "font-mono text-xs",
                    api_key.status == :active && "text-muted",
                    api_key.status == :revoked && "text-muted/40"
                  ]}>
                    {if api_key.type == :private, do: "sk_***", else: "pk_***"}
                  </span>
                </div>

                <%!-- Owner --%>
                <div class="hidden sm:block text-sm text-muted w-40 truncate text-right font-mono">
                  {api_key.account_user.user.email |> String.split("@") |> hd()}
                </div>

                <%!-- Type badge --%>
                <div class="w-20 flex justify-end">
                  <span class={[
                    "status-badge",
                    api_key.type == :private && "status-badge-pending",
                    api_key.type == :public && "status-badge-active"
                  ]}>
                    {if api_key.type == :private, do: "WRITE", else: "READ"}
                  </span>
                </div>

                <%!-- Date --%>
                <div class="hidden lg:block text-sm text-muted w-32 text-right font-mono">
                  {format_datetime(api_key.inserted_at)}
                </div>

                <%!-- Actions --%>
                <div class="w-20 flex justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <%= if @can_manage && api_key.status == :active do %>
                    <button
                      phx-click="revoke"
                      phx-value-id={api_key.id}
                      data-confirm="Are you sure you want to revoke this API key? This action cannot be undone."
                      class="p-2 rounded-sm hover:bg-error/15 text-error/60 hover:text-error transition-colors"
                      onclick="event.preventDefault(); event.stopPropagation();"
                    >
                      <.icon name="hero-trash" class="size-4" />
                    </button>
                  <% end %>
                </div>
              </.link>
            <% end %>
          </div>

          <%!-- Empty state with terminal aesthetic --%>
          <div :if={@total == 0} class="flex flex-col items-center justify-center py-20 text-muted">
            <div class="size-16 rounded-sm bg-base-200 border border-base-300 flex items-center justify-center mb-6">
              <.icon name="hero-key" class="size-8 opacity-30" />
            </div>
            <div class="font-mono text-sm mb-2">$ fruitfly keys list</div>
            <div class="font-mono text-xs text-muted mb-6">No API keys found.</div>
            <.link
              :if={@can_manage}
              navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/new"}
              class="btn-action"
            >
              Create your first key
            </.link>
          </div>
        </div>

        <%!-- Footer with pagination --%>
        <div
          :if={@total > 0}
          class="px-6 py-3 border-t border-base-300/50 flex items-center justify-between bg-base-100"
        >
          <span class="font-mono text-xs text-muted">
            [{@page * 20 - 19}-{min(@page * 20, @total)}] of {@total}
          </span>

          <div :if={@total_pages > 1} class="flex items-center gap-2">
            <.link
              :if={@page > 1}
              patch={
                pagination_path(
                  @current_scope.account.slug,
                  @search,
                  @status_filter,
                  @type_filter,
                  @page - 1
                )
              }
              class="btn-subtle py-1.5 px-3 font-mono text-xs"
            >
              <.icon name="hero-chevron-left" class="size-3.5" />
            </.link>
            <span class="font-mono text-xs text-muted px-2">
              {@page}/{@total_pages}
            </span>
            <.link
              :if={@page < @total_pages}
              patch={
                pagination_path(
                  @current_scope.account.slug,
                  @search,
                  @status_filter,
                  @type_filter,
                  @page + 1
                )
              }
              class="btn-subtle py-1.5 px-3 font-mono text-xs"
            >
              <.icon name="hero-chevron-right" class="size-3.5" />
            </.link>
          </div>
        </div>

        <%!-- Info banner for read-only users --%>
        <div
          :if={!@can_manage}
          class="mx-6 mb-4 px-4 py-3 rounded-sm bg-info/10 border border-info/20 flex items-center gap-3"
        >
          <.icon name="hero-information-circle" class="size-5 text-info" />
          <span class="font-mono text-xs text-info">
            // READ-ONLY ACCESS — Contact an admin to create or revoke API keys.
          </span>
        </div>
      </div>
    </FFWeb.Layouts.dashboard>
    """
  end
end
