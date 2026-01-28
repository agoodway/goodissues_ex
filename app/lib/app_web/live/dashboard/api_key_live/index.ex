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
    <FFWeb.Layouts.dashboard flash={@flash} current_scope={@current_scope} page_title={@page_title}>
      <div class="h-full flex flex-col">
        <%!-- Page header with filters --%>
        <div class="px-6 py-4 border-b border-base-300/50">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-3">
              <.icon name="hero-key" class="size-5 text-muted" />
              <h1 class="text-lg font-semibold">API Keys</h1>
              <span class="text-sm text-muted">{@total}</span>
            </div>
            <.link
              :if={@can_manage}
              navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/new"}
              class="btn-subtle flex items-center gap-1.5"
            >
              <.icon name="hero-plus" class="size-4" />
              <span>New Key</span>
            </.link>
          </div>

          <%!-- Filters row --%>
          <div class="flex items-center gap-3">
            <form phx-change="search" phx-submit="search" class="flex-1 max-w-xs">
              <div class="relative">
                <.icon name="hero-funnel" class="size-4 absolute left-2.5 top-1/2 -translate-y-1/2 icon-muted" />
                <input
                  type="text"
                  name="search"
                  value={@search}
                  placeholder="Filter..."
                  phx-debounce="300"
                  class="input-search w-full pl-8 py-1.5 text-sm"
                />
              </div>
            </form>

            <form phx-change="filter_status">
              <select name="status" class="select-minimal">
                <option value="" selected={@status_filter == ""}>All Statuses</option>
                <option value="active" selected={@status_filter == "active"}>Active</option>
                <option value="revoked" selected={@status_filter == "revoked"}>Revoked</option>
              </select>
            </form>

            <form phx-change="filter_type">
              <select name="type" class="select-minimal">
                <option value="" selected={@type_filter == ""}>All Types</option>
                <option value="public" selected={@type_filter == "public"}>Public</option>
                <option value="private" selected={@type_filter == "private"}>Private</option>
              </select>
            </form>
          </div>
        </div>

        <%!-- List content --%>
        <div class="flex-1 overflow-auto">
          <%!-- Group header --%>
          <div :if={@total > 0} class="group-header">
            <div class="flex items-center gap-2">
              <.icon name="hero-key" class="size-4" />
              <span>Active Keys</span>
              <span class="text-xs opacity-60">{length(Enum.filter(@api_keys, & &1.status == :active))}</span>
            </div>
          </div>

          <%!-- API Keys list --%>
          <div id="api-keys-list">
            <%= for api_key <- @api_keys do %>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/#{api_key.id}"}
                class="list-item group cursor-pointer"
                id={"api-key-#{api_key.id}"}
              >
                <%!-- Status indicator --%>
                <div class="w-6 flex justify-center">
                  <div class={[
                    "size-4 rounded-full flex items-center justify-center",
                    api_key.status == :active && "text-success",
                    api_key.status == :revoked && "text-error opacity-50"
                  ]}>
                    <.icon name={if api_key.status == :active, do: "hero-check-circle", else: "hero-x-circle"} class="size-4" />
                  </div>
                </div>

                <%!-- Key name --%>
                <div class="flex-1 min-w-0 ml-2">
                  <span class={[
                    "font-medium",
                    api_key.status == :revoked && "line-through opacity-50"
                  ]}>
                    {api_key.name}
                  </span>
                </div>

                <%!-- Owner --%>
                <div class="hidden sm:block text-sm text-muted w-48 truncate">
                  {api_key.account_user.user.email}
                </div>

                <%!-- Type badge --%>
                <div class="w-20">
                  <span class={[
                    "tag-badge text-xs",
                    api_key.type == :private && "!bg-warning/20 !text-warning"
                  ]}>
                    {api_key.type}
                  </span>
                </div>

                <%!-- Date --%>
                <div class="hidden lg:block text-sm text-muted w-28">
                  {format_datetime(api_key.inserted_at)}
                </div>

                <%!-- Actions --%>
                <div class="w-20 flex justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <%= if @can_manage && api_key.status == :active do %>
                    <button
                      phx-click="revoke"
                      phx-value-id={api_key.id}
                      data-confirm="Are you sure you want to revoke this API key? This cannot be undone."
                      class="p-1.5 rounded hover:bg-error/20 text-error/70 hover:text-error"
                      onclick="event.preventDefault(); event.stopPropagation();"
                    >
                      <.icon name="hero-trash" class="size-4" />
                    </button>
                  <% end %>
                </div>
              </.link>
            <% end %>
          </div>

          <%!-- Empty state --%>
          <div :if={@total == 0} class="flex flex-col items-center justify-center py-16 text-muted">
            <.icon name="hero-key" class="size-12 opacity-30 mb-4" />
            <p class="text-sm">No API keys found</p>
            <.link
              :if={@can_manage}
              navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/new"}
              class="btn-subtle mt-4"
            >
              Create your first key
            </.link>
          </div>
        </div>

        <%!-- Footer with pagination --%>
        <div :if={@total > 0} class="px-6 py-3 border-t border-base-300/50 flex items-center justify-between text-sm text-muted">
          <span>Showing {@page * 20 - 19} - {min(@page * 20, @total)} of {@total}</span>

          <div :if={@total_pages > 1} class="flex items-center gap-2">
            <.link
              :if={@page > 1}
              patch={pagination_path(@current_scope.account.slug, @search, @status_filter, @type_filter, @page - 1)}
              class="btn-subtle py-1 px-2"
            >
              <.icon name="hero-chevron-left" class="size-4" />
            </.link>
            <span>Page {@page} of {@total_pages}</span>
            <.link
              :if={@page < @total_pages}
              patch={pagination_path(@current_scope.account.slug, @search, @status_filter, @type_filter, @page + 1)}
              class="btn-subtle py-1 px-2"
            >
              <.icon name="hero-chevron-right" class="size-4" />
            </.link>
          </div>
        </div>

        <%!-- Info banner for read-only users --%>
        <div :if={!@can_manage} class="mx-6 mb-4 px-4 py-3 rounded-lg bg-info/10 border border-info/20 flex items-center gap-3 text-sm">
          <.icon name="hero-information-circle" class="size-5 text-info" />
          <span class="text-info">You have read-only access. Contact an admin to create or revoke API keys.</span>
        </div>
      </div>
    </FFWeb.Layouts.dashboard>
    """
  end
end
