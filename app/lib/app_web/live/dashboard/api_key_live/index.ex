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
      <.header>
        API Keys
        <:subtitle>Manage API keys for {@current_scope.account.name}</:subtitle>
        <:actions>
          <.link
            :if={@can_manage}
            navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/new"}
            class="btn btn-primary"
          >
            <.icon name="hero-plus" class="size-4 mr-1" /> New API Key
          </.link>
        </:actions>
      </.header>

      <div class="flex flex-col sm:flex-row gap-4 mb-6">
        <form phx-change="search" phx-submit="search" class="flex-1">
          <.input
            type="text"
            name="search"
            value={@search}
            placeholder="Search by name or owner email..."
            phx-debounce="300"
          />
        </form>

        <form phx-change="filter_status" class="w-full sm:w-40">
          <.input
            type="select"
            name="status"
            value={@status_filter}
            options={[{"All Statuses", ""}, {"Active", "active"}, {"Revoked", "revoked"}]}
          />
        </form>

        <form phx-change="filter_type" class="w-full sm:w-40">
          <.input
            type="select"
            name="type"
            value={@type_filter}
            options={[{"All Types", ""}, {"Public", "public"}, {"Private", "private"}]}
          />
        </form>
      </div>

      <div class="overflow-x-auto">
        <.table id="api-keys" rows={@api_keys} row_id={fn api_key -> "api-key-#{api_key.id}" end}>
          <:col :let={api_key} label="Name">{api_key.name}</:col>
          <:col :let={api_key} label="Type">
            <span class={[
              "badge badge-sm",
              api_key.type == :private && "badge-warning",
              api_key.type == :public && "badge-info"
            ]}>
              {api_key.type}
            </span>
          </:col>
          <:col :let={api_key} label="Owner">{api_key.account_user.user.email}</:col>
          <:col :let={api_key} label="Status">
            <span class={[
              "badge badge-sm",
              api_key.status == :active && "badge-success",
              api_key.status == :revoked && "badge-error"
            ]}>
              {api_key.status}
            </span>
          </:col>
          <:col :let={api_key} label="Last Used">{format_datetime(api_key.last_used_at)}</:col>
          <:col :let={api_key} label="Expires">{format_datetime(api_key.expires_at)}</:col>
          <:action :let={api_key}>
            <.link
              navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/#{api_key.id}"}
              class="btn btn-ghost btn-xs"
            >
              View
            </.link>
          </:action>
          <:action :let={api_key}>
            <%= if @can_manage && api_key.status == :active do %>
              <button
                phx-click="revoke"
                phx-value-id={api_key.id}
                data-confirm="Are you sure you want to revoke this API key? This cannot be undone."
                class="btn btn-ghost btn-xs text-error"
              >
                Revoke
              </button>
            <% end %>
          </:action>
        </.table>
      </div>

      <div :if={@total == 0} class="text-center py-12 text-base-content/70">
        No API keys found.
      </div>

      <div :if={@total_pages > 1} class="flex justify-center mt-6">
        <div class="join">
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
            class="join-item btn"
          >
            Previous
          </.link>
          <span class="join-item btn btn-disabled">
            Page {@page} of {@total_pages}
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
            class="join-item btn"
          >
            Next
          </.link>
        </div>
      </div>

      <div :if={@total > 0} class="text-sm text-base-content/70 mt-4 text-center">
        Showing {@page * 20 - 19} - {min(@page * 20, @total)} of {@total} API keys
      </div>

      <div :if={!@can_manage} class="alert alert-info mt-6">
        <.icon name="hero-information-circle" class="size-5" />
        <span>You have read-only access. Contact an admin to create or revoke API keys.</span>
      </div>
    </FFWeb.Layouts.dashboard>
    """
  end
end
