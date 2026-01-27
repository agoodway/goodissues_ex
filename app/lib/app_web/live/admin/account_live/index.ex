defmodule FFWeb.Admin.AccountLive.Index do
  use FFWeb, :live_view

  alias FF.Accounts
  alias FF.Accounts.Account

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    page = String.to_integer(params["page"] || "1")
    search = params["search"] || ""
    status = params["status"] || ""

    result = Accounts.list_accounts(page: page, search: search, status: status)

    socket
    |> assign(:page_title, "Accounts")
    |> assign(:account, nil)
    |> assign(:accounts, result.accounts)
    |> assign(:page, result.page)
    |> assign(:total_pages, result.total_pages)
    |> assign(:total, result.total)
    |> assign(:search, search)
    |> assign(:status_filter, status)
    |> assign(:return_to, build_return_path(search, status, page))
  end

  defp apply_action(socket, :new, params) do
    socket
    |> apply_action(:index, params)
    |> assign(:page_title, "New Account")
    |> assign(:account, %Account{})
  end

  defp apply_action(socket, :edit, %{"id" => id} = params) do
    account = Accounts.get_account!(id)

    socket
    |> apply_action(:index, params)
    |> assign(:page_title, "Edit Account")
    |> assign(:account, account)
  end

  defp build_return_path(search, status, page) do
    pagination_path(search, status, page)
  end

  defp pagination_path(search, status, page) do
    params =
      %{search: search, status: status, page: page}
      |> Enum.reject(fn {_k, v} -> v == "" or v == 1 end)

    ~p"/admin/accounts?#{params}"
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply,
     push_patch(socket,
       to: pagination_path(search, socket.assigns.status_filter, 1)
     )}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     push_patch(socket,
       to: pagination_path(socket.assigns.search, status, 1)
     )}
  end

  @impl true
  def handle_event("suspend", %{"id" => id}, socket) do
    account = Accounts.get_account!(id)

    case Accounts.suspend_account(account) do
      {:ok, _account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account suspended successfully.")
         |> push_patch(to: socket.assigns.return_to)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to suspend account.")}
    end
  end

  @impl true
  def handle_event("activate", %{"id" => id}, socket) do
    account = Accounts.get_account!(id)

    case Accounts.activate_account(account) do
      {:ok, _account} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account activated successfully.")
         |> push_patch(to: socket.assigns.return_to)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to activate account.")}
    end
  end

  @impl true
  def handle_info({FFWeb.Admin.AccountLive.FormComponent, {:saved, _account}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Account saved successfully.")
     |> push_patch(to: socket.assigns.return_to)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <FFWeb.Layouts.admin flash={@flash} current_scope={@current_scope} page_title={@page_title}>
      <.header>
        Accounts
        <:subtitle>Manage all accounts in the system</:subtitle>
        <:actions>
          <.link patch={~p"/admin/accounts/new"} class="btn btn-primary">
            <.icon name="hero-plus" class="size-4 mr-1" /> New Account
          </.link>
        </:actions>
      </.header>

      <div class="flex flex-col sm:flex-row gap-4 mb-6">
        <form phx-change="search" phx-submit="search" class="flex-1">
          <.input
            type="text"
            name="search"
            value={@search}
            placeholder="Search by name or slug..."
            phx-debounce="300"
          />
        </form>

        <form phx-change="filter_status" class="w-full sm:w-48">
          <.input
            type="select"
            name="status"
            value={@status_filter}
            options={[{"All Statuses", ""}, {"Active", "active"}, {"Suspended", "suspended"}]}
          />
        </form>
      </div>

      <div class="overflow-x-auto">
        <.table id="accounts" rows={@accounts} row_id={fn account -> "account-#{account.id}" end}>
          <:col :let={account} label="Name">{account.name}</:col>
          <:col :let={account} label="Slug">{account.slug}</:col>
          <:col :let={account} label="Status">
            <span class={[
              "badge",
              account.status == :active && "badge-success",
              account.status == :suspended && "badge-error"
            ]}>
              {account.status}
            </span>
          </:col>
          <:col :let={account} label="Members">
            {length(account.account_users)}
          </:col>
          <:col :let={account} label="Created">
            {Calendar.strftime(account.inserted_at, "%Y-%m-%d")}
          </:col>
          <:action :let={account}>
            <.link navigate={~p"/admin/accounts/#{account.id}"} class="btn btn-ghost btn-xs">
              View
            </.link>
          </:action>
          <:action :let={account}>
            <.link patch={~p"/admin/accounts/#{account.id}/edit"} class="btn btn-ghost btn-xs">
              Edit
            </.link>
          </:action>
          <:action :let={account}>
            <%= if account.status == :active do %>
              <button
                phx-click="suspend"
                phx-value-id={account.id}
                data-confirm="Are you sure you want to suspend this account?"
                class="btn btn-ghost btn-xs text-error"
              >
                Suspend
              </button>
            <% else %>
              <button
                phx-click="activate"
                phx-value-id={account.id}
                class="btn btn-ghost btn-xs text-success"
              >
                Activate
              </button>
            <% end %>
          </:action>
        </.table>
      </div>

      <div :if={@total_pages > 1} class="flex justify-center mt-6">
        <div class="join">
          <.link
            :if={@page > 1}
            patch={pagination_path(@search, @status_filter, @page - 1)}
            class="join-item btn"
          >
            Previous
          </.link>
          <span class="join-item btn btn-disabled">
            Page {@page} of {@total_pages}
          </span>
          <.link
            :if={@page < @total_pages}
            patch={pagination_path(@search, @status_filter, @page + 1)}
            class="join-item btn"
          >
            Next
          </.link>
        </div>
      </div>

      <div class="text-sm text-base-content/70 mt-4 text-center">
        Showing {@page * 20 - 19} - {min(@page * 20, @total)} of {@total} accounts
      </div>

      <.modal
        :if={@live_action in [:new, :edit]}
        id="account-modal"
        show
        on_cancel={JS.patch(@return_to)}
      >
        <.live_component
          module={FFWeb.Admin.AccountLive.FormComponent}
          id={@account.id || :new}
          title={@page_title}
          action={@live_action}
          account={@account}
          patch={@return_to}
        />
      </.modal>
    </FFWeb.Layouts.admin>
    """
  end
end
