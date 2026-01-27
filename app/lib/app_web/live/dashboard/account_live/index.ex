defmodule FFWeb.Dashboard.AccountLive.Index do
  @moduledoc """
  Dashboard view showing the current account settings.

  Unlike the admin view which showed all accounts, the dashboard shows
  only the currently selected account with management based on role.
  """
  use FFWeb, :live_view

  alias FF.Accounts
  alias FF.Accounts.Scope

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    account = socket.assigns.current_scope.account

    socket
    |> assign(:page_title, "Account Settings")
    |> assign(:account, Accounts.get_account!(account.id))
    |> assign(:can_manage, Scope.can_manage_account?(socket.assigns.current_scope))
  end

  defp apply_action(socket, :edit, _params) do
    account = socket.assigns.current_scope.account

    if Scope.can_manage_account?(socket.assigns.current_scope) do
      socket
      |> assign(:page_title, "Edit Account")
      |> assign(:account, Accounts.get_account!(account.id))
      |> assign(:can_manage, true)
    else
      socket
      |> put_flash(:error, "You don't have permission to edit this account.")
      |> push_navigate(to: ~p"/dashboard/#{account.slug}")
    end
  end

  @impl true
  def handle_event("suspend", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      case Accounts.suspend_account(socket.assigns.account) do
        {:ok, account} ->
          {:noreply,
           socket
           |> put_flash(:info, "Account suspended successfully.")
           |> assign(:account, Accounts.get_account!(account.id))}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to suspend account.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to suspend this account.")}
    end
  end

  @impl true
  def handle_event("activate", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      case Accounts.activate_account(socket.assigns.account) do
        {:ok, account} ->
          {:noreply,
           socket
           |> put_flash(:info, "Account activated successfully.")
           |> assign(:account, Accounts.get_account!(account.id))}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to activate account.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to activate this account.")}
    end
  end

  @impl true
  def handle_info({FFWeb.Dashboard.AccountLive.FormComponent, {:saved, account}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Account updated successfully.")
     |> assign(:account, Accounts.get_account!(account.id))
     |> push_patch(to: ~p"/dashboard/#{account.slug}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <FFWeb.Layouts.dashboard flash={@flash} current_scope={@current_scope} page_title={@page_title}>
      <.header>
        Account Settings
        <:subtitle>
          Manage your account settings and details
        </:subtitle>
        <:actions>
          <.link
            :if={@can_manage}
            patch={~p"/dashboard/#{@account.slug}/settings"}
            class="btn btn-primary btn-sm"
          >
            <.icon name="hero-pencil" class="size-4 mr-1" /> Edit
          </.link>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Account Details</h2>
            <.list>
              <:item title="Name">{@account.name}</:item>
              <:item title="Slug">{@account.slug}</:item>
              <:item title="Status">
                <span class={[
                  "badge",
                  @account.status == :active && "badge-success",
                  @account.status == :suspended && "badge-error"
                ]}>
                  {@account.status}
                </span>
              </:item>
              <:item title="Created">{Calendar.strftime(@account.inserted_at, "%Y-%m-%d")}</:item>
            </.list>

            <div :if={@can_manage} class="card-actions justify-end mt-4">
              <%= if @account.status == :active do %>
                <button
                  phx-click="suspend"
                  data-confirm="Are you sure you want to suspend this account? All users will lose access."
                  class="btn btn-error btn-sm"
                >
                  <.icon name="hero-no-symbol" class="size-4 mr-1" /> Suspend Account
                </button>
              <% else %>
                <button phx-click="activate" class="btn btn-success btn-sm">
                  <.icon name="hero-check-circle" class="size-4 mr-1" /> Activate Account
                </button>
              <% end %>
            </div>
          </div>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Members ({length(@account.account_users)})</h2>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Email</th>
                    <th>Role</th>
                    <th>Joined</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for account_user <- @account.account_users do %>
                    <tr>
                      <td>{account_user.user.email}</td>
                      <td>
                        <span class={[
                          "badge badge-sm",
                          account_user.role == :owner && "badge-primary",
                          account_user.role == :admin && "badge-secondary",
                          account_user.role == :member && "badge-ghost"
                        ]}>
                          {account_user.role}
                        </span>
                      </td>
                      <td>{Calendar.strftime(account_user.inserted_at, "%Y-%m-%d")}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <div :if={!@can_manage} class="alert alert-info mt-6">
        <.icon name="hero-information-circle" class="size-5" />
        <span>You have read-only access to this account. Contact an admin to make changes.</span>
      </div>

      <.modal
        :if={@live_action == :edit}
        id="account-modal"
        show
        on_cancel={JS.patch(~p"/dashboard/#{@account.slug}")}
      >
        <.live_component
          module={FFWeb.Dashboard.AccountLive.FormComponent}
          id={@account.id}
          title="Edit Account"
          action={:edit}
          account={@account}
          patch={~p"/dashboard/#{@account.slug}"}
        />
      </.modal>
    </FFWeb.Layouts.dashboard>
    """
  end
end
