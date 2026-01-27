defmodule FFWeb.Admin.AccountLive.Show do
  use FFWeb, :live_view

  alias FF.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    account = Accounts.get_account!(id)

    {:noreply,
     socket
     |> assign(:page_title, account.name)
     |> assign(:account, account)}
  end

  @impl true
  def handle_event("suspend", _params, socket) do
    case Accounts.suspend_account(socket.assigns.account) do
      {:ok, account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account suspended successfully.")
         |> assign(:account, Accounts.get_account!(account.id))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to suspend account.")}
    end
  end

  @impl true
  def handle_event("activate", _params, socket) do
    case Accounts.activate_account(socket.assigns.account) do
      {:ok, account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account activated successfully.")
         |> assign(:account, Accounts.get_account!(account.id))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to activate account.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <FFWeb.Layouts.admin flash={@flash} current_scope={@current_scope} page_title={@page_title}>
      <.header>
        {@account.name}
        <:subtitle>
          <span class={[
            "badge",
            @account.status == :active && "badge-success",
            @account.status == :suspended && "badge-error"
          ]}>
            {@account.status}
          </span>
        </:subtitle>
        <:actions>
          <.link navigate={~p"/admin/accounts/#{@account.id}/edit"} class="btn btn-primary btn-sm">
            <.icon name="hero-pencil" class="size-4 mr-1" /> Edit
          </.link>
          <%= if @account.status == :active do %>
            <button
              phx-click="suspend"
              data-confirm="Are you sure you want to suspend this account? All users will lose access."
              class="btn btn-error btn-sm"
            >
              <.icon name="hero-no-symbol" class="size-4 mr-1" /> Suspend
            </button>
          <% else %>
            <button phx-click="activate" class="btn btn-success btn-sm">
              <.icon name="hero-check-circle" class="size-4 mr-1" /> Activate
            </button>
          <% end %>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Account Details</h2>
            <.list>
              <:item title="ID">{@account.id}</:item>
              <:item title="Slug">{@account.slug}</:item>
              <:item title="Created">{Calendar.strftime(@account.inserted_at, "%Y-%m-%d %H:%M:%S UTC")}</:item>
              <:item title="Updated">{Calendar.strftime(@account.updated_at, "%Y-%m-%d %H:%M:%S UTC")}</:item>
            </.list>
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

      <div class="mt-6">
        <.link navigate={~p"/admin/accounts"} class="btn btn-ghost">
          <.icon name="hero-arrow-left" class="size-4 mr-1" /> Back to Accounts
        </.link>
      </div>
    </FFWeb.Layouts.admin>
    """
  end
end
