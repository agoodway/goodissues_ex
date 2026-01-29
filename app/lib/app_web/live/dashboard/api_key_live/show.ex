defmodule FFWeb.Dashboard.ApiKeyLive.Show do
  @moduledoc """
  Dashboard view for showing a single API key scoped to the current account.

  Verifies the API key belongs to the current account before displaying.
  Only users with owner/admin role can revoke keys.
  """
  use FFWeb, :live_view

  alias FF.Accounts
  alias FF.Accounts.Scope

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :can_manage, Scope.can_manage_account?(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    account = socket.assigns.current_scope.account

    case Accounts.get_account_api_key(account, id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "API key not found.")
         |> push_navigate(
           to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/api-keys"
         )}

      api_key ->
        {:noreply,
         socket
         |> assign(:page_title, api_key.name)
         |> assign(:api_key, api_key)}
    end
  end

  @impl true
  def handle_event("revoke", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      case Accounts.revoke_api_key(socket.assigns.api_key) do
        {:ok, api_key} ->
          account = socket.assigns.current_scope.account

          {:noreply,
           socket
           |> put_flash(:info, "API key revoked successfully.")
           |> assign(:api_key, Accounts.get_account_api_key!(account, api_key.id))}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to revoke API key.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to revoke API keys.")}
    end
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp format_scopes([]), do: "All scopes"
  defp format_scopes(scopes), do: Enum.join(scopes, ", ")

  @impl true
  def render(assigns) do
    ~H"""
    <FFWeb.Layouts.dashboard flash={@flash} current_scope={@current_scope} page_title={@page_title} active_nav={:api_keys}>
      <.header>
        {@api_key.name}
        <:subtitle>
          <span class={[
            "badge",
            @api_key.status == :active && "badge-success",
            @api_key.status == :revoked && "badge-error"
          ]}>
            {@api_key.status}
          </span>
          <span class={[
            "badge ml-2",
            @api_key.type == :private && "badge-warning",
            @api_key.type == :public && "badge-info"
          ]}>
            {@api_key.type}
          </span>
        </:subtitle>
        <:actions>
          <%= if @can_manage && @api_key.status == :active do %>
            <button
              phx-click="revoke"
              data-confirm="Are you sure you want to revoke this API key? This cannot be undone."
              class="btn btn-error btn-sm"
            >
              <.icon name="hero-no-symbol" class="size-4 mr-1" /> Revoke
            </button>
          <% end %>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">API Key Details</h2>
            <.list>
              <:item title="ID">{@api_key.id}</:item>
              <:item title="Name">{@api_key.name}</:item>
              <:item title="Type">
                <span class={[
                  "badge badge-sm",
                  @api_key.type == :private && "badge-warning",
                  @api_key.type == :public && "badge-info"
                ]}>
                  {@api_key.type}
                </span>
              </:item>
              <:item title="Token Prefix">
                <code class="bg-base-300 px-2 py-1 rounded text-sm">{@api_key.token_prefix}...</code>
              </:item>
              <:item title="Status">
                <span class={[
                  "badge badge-sm",
                  @api_key.status == :active && "badge-success",
                  @api_key.status == :revoked && "badge-error"
                ]}>
                  {@api_key.status}
                </span>
              </:item>
              <:item title="Scopes">{format_scopes(@api_key.scopes)}</:item>
            </.list>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Owner Information</h2>
            <.list>
              <:item title="User Email">{@api_key.account_user.user.email}</:item>
              <:item title="Account">{@api_key.account_user.account.name}</:item>
              <:item title="Account Slug">{@api_key.account_user.account.slug}</:item>
              <:item title="Role in Account">
                <span class={[
                  "badge badge-sm",
                  @api_key.account_user.role == :owner && "badge-primary",
                  @api_key.account_user.role == :admin && "badge-secondary",
                  @api_key.account_user.role == :member && "badge-ghost"
                ]}>
                  {@api_key.account_user.role}
                </span>
              </:item>
            </.list>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Activity</h2>
            <.list>
              <:item title="Created">{format_datetime(@api_key.inserted_at)}</:item>
              <:item title="Last Updated">{format_datetime(@api_key.updated_at)}</:item>
              <:item title="Last Used">{format_datetime(@api_key.last_used_at)}</:item>
              <:item title="Expires">{format_datetime(@api_key.expires_at)}</:item>
            </.list>
          </div>
        </div>
      </div>

      <div :if={!@can_manage} class="alert alert-info mt-6">
        <.icon name="hero-information-circle" class="size-5" />
        <span>You have read-only access. Contact an admin to revoke this API key.</span>
      </div>

      <div class="mt-6">
        <.link navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys"} class="btn btn-ghost">
          <.icon name="hero-arrow-left" class="size-4 mr-1" /> Back to API Keys
        </.link>
      </div>
    </FFWeb.Layouts.dashboard>
    """
  end
end
