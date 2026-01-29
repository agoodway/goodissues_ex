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
    <FFWeb.Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      active_nav={:settings}
    >
      <div class="max-w-5xl">
        <%!-- Page header --%>
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-4">
            <div class="size-10 rounded-sm bg-primary/10 border border-primary/20 flex items-center justify-center">
              <.icon name="hero-building-office" class="size-5 text-primary" />
            </div>
            <div>
              <h1 class="text-lg font-semibold text-base-content">Account Settings</h1>
              <p class="font-mono text-xs text-muted mt-0.5">
                Manage your account settings and details
              </p>
            </div>
          </div>
          <.link
            :if={@can_manage}
            patch={~p"/dashboard/#{@account.slug}/settings"}
            class="btn-action flex items-center gap-2"
          >
            <.icon name="hero-pencil" class="size-4" />
            <span>Edit</span>
          </.link>
        </div>

        <%!-- Content grid --%>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <%!-- Account Details Card --%>
          <div class="rounded-sm border border-base-300/50 bg-base-200/30">
            <div class="px-4 py-3 border-b border-base-300/50">
              <h2 class="font-mono text-xs text-muted uppercase tracking-wider">
                // Account Details
              </h2>
            </div>
            <div class="p-4 space-y-3">
              <div class="flex items-center justify-between py-2 border-b border-base-300/30">
                <span class="text-xs text-muted">Name</span>
                <span class="text-sm font-medium">{@account.name}</span>
              </div>
              <div class="flex items-center justify-between py-2 border-b border-base-300/30">
                <span class="text-xs text-muted">Slug</span>
                <span class="font-mono text-sm">{@account.slug}</span>
              </div>
              <div class="flex items-center justify-between py-2 border-b border-base-300/30">
                <span class="text-xs text-muted">Status</span>
                <span class={[
                  "status-badge",
                  @account.status == :active && "status-badge-active",
                  @account.status == :suspended && "status-badge-revoked"
                ]}>
                  {@account.status |> to_string() |> String.upcase()}
                </span>
              </div>
              <div class="flex items-center justify-between py-2">
                <span class="text-xs text-muted">Created</span>
                <span class="font-mono text-sm">
                  {Calendar.strftime(@account.inserted_at, "%Y-%m-%d")}
                </span>
              </div>
            </div>

            <div :if={@can_manage} class="px-4 py-3 border-t border-base-300/50 flex justify-end">
              <%= if @account.status == :active do %>
                <button
                  phx-click="suspend"
                  data-confirm="Are you sure you want to suspend this account? All users will lose access."
                  class="btn-subtle text-error/70 hover:text-error hover:border-error/30 flex items-center gap-2"
                >
                  <.icon name="hero-no-symbol" class="size-4" />
                  <span>Suspend</span>
                </button>
              <% else %>
                <button phx-click="activate" class="btn-action flex items-center gap-2">
                  <.icon name="hero-check-circle" class="size-4" />
                  <span>Activate</span>
                </button>
              <% end %>
            </div>
          </div>

          <%!-- Members Card --%>
          <div class="rounded-sm border border-base-300/50 bg-base-200/30">
            <div class="px-4 py-3 border-b border-base-300/50 flex items-center justify-between">
              <h2 class="font-mono text-xs text-muted uppercase tracking-wider">// Members</h2>
              <span class="font-mono text-xs text-muted">[{length(@account.account_users)}]</span>
            </div>
            <div class="divide-y divide-base-300/30">
              <%= for account_user <- @account.account_users do %>
                <div class="px-4 py-3 flex items-center gap-3">
                  <div class="size-8 rounded-sm bg-primary/10 border border-primary/20 flex items-center justify-center">
                    <span class="font-mono text-xs font-bold text-primary">
                      {String.first(account_user.user.email) |> String.upcase()}
                    </span>
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="text-sm font-medium truncate">{account_user.user.email}</div>
                    <div class="font-mono text-[10px] text-muted">
                      Joined {Calendar.strftime(account_user.inserted_at, "%Y-%m-%d")}
                    </div>
                  </div>
                  <span class={[
                    "status-badge",
                    account_user.role == :owner && "status-badge-active",
                    account_user.role == :admin && "status-badge-pending",
                    account_user.role == :member && ""
                  ]}>
                    {account_user.role |> to_string() |> String.upcase()}
                  </span>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Read-only info banner --%>
        <div
          :if={!@can_manage}
          class="mt-4 px-4 py-3 rounded-sm bg-info/10 border border-info/20 flex items-center gap-3"
        >
          <.icon name="hero-information-circle" class="size-5 text-info" />
          <span class="font-mono text-xs text-info">
            // READ-ONLY ACCESS — Contact an admin to make changes.
          </span>
        </div>
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
