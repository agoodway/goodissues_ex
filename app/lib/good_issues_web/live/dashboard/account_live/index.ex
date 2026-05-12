defmodule GIWeb.Dashboard.AccountLive.Index do
  @moduledoc """
  Dashboard view showing the current account settings.

  Unlike the admin view which showed all accounts, the dashboard shows
  only the currently selected account with management based on role.
  """
  use GIWeb, :live_view

  alias GI.Accounts
  alias GI.Accounts.Scope
  alias GI.TelegramProfiles
  alias GI.TelegramProfiles.TelegramProfile

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
    |> assign_telegram_profile(account.id)
  end

  defp apply_action(socket, :edit, _params) do
    account = socket.assigns.current_scope.account

    if Scope.can_manage_account?(socket.assigns.current_scope) do
      socket
      |> assign(:page_title, "Edit Account")
      |> assign(:account, Accounts.get_account!(account.id))
      |> assign(:can_manage, true)
      |> assign_telegram_profile(account.id)
    else
      socket
      |> put_flash(:error, "You don't have permission to edit this account.")
      |> push_navigate(to: ~p"/dashboard/#{account.slug}")
    end
  end

  defp assign_telegram_profile(socket, account_id) do
    profile = TelegramProfiles.get_by_account(account_id)

    socket
    |> assign(:telegram_profile, profile)
    |> assign(
      :telegram_changeset,
      TelegramProfiles.change_telegram_profile(profile || %TelegramProfile{}, %{})
    )
    |> assign(:telegram_editing, false)
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
  def handle_event("toggle_telegram_edit", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      {:noreply, assign(socket, :telegram_editing, !socket.assigns.telegram_editing)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_telegram", %{"telegram_profile" => params}, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      account = socket.assigns.account

      case socket.assigns.telegram_profile do
        nil ->
          params = Map.put(params, "account_id", account.id)

          case TelegramProfiles.create_telegram_profile(params) do
            {:ok, _profile} ->
              {:noreply,
               socket
               |> put_flash(:info, "Telegram profile created.")
               |> assign_telegram_profile(account.id)}

            {:error, changeset} ->
              {:noreply, assign(socket, :telegram_changeset, changeset)}
          end

        profile ->
          # If bot_token is empty, don't update it
          params =
            case params["bot_token"] do
              nil -> Map.delete(params, "bot_token")
              "" -> Map.delete(params, "bot_token")
              _token -> params
            end

          case TelegramProfiles.update_telegram_profile(profile, params) do
            {:ok, _profile} ->
              {:noreply,
               socket
               |> put_flash(:info, "Telegram profile updated.")
               |> assign_telegram_profile(account.id)}

            {:error, changeset} ->
              {:noreply, assign(socket, :telegram_changeset, changeset)}
          end
      end
    else
      {:noreply,
       put_flash(socket, :error, "You don't have permission to manage Telegram settings.")}
    end
  end

  @impl true
  def handle_event("delete_telegram", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      case socket.assigns.telegram_profile do
        nil ->
          {:noreply, socket}

        profile ->
          case TelegramProfiles.delete_telegram_profile(profile) do
            {:ok, _} ->
              {:noreply,
               socket
               |> put_flash(:info, "Telegram profile removed.")
               |> assign_telegram_profile(socket.assigns.account.id)}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to remove Telegram profile.")}
          end
      end
    else
      {:noreply,
       put_flash(socket, :error, "You don't have permission to manage Telegram settings.")}
    end
  end

  @impl true
  def handle_info({GIWeb.Dashboard.AccountLive.FormComponent, {:saved, account}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Account updated successfully.")
     |> assign(:account, Accounts.get_account!(account.id))
     |> push_patch(to: ~p"/dashboard/#{account.slug}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <GIWeb.Layouts.dashboard
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

        <%!-- Telegram Settings Card --%>
        <div class="mt-4 rounded-sm border border-base-300/50 bg-base-200/30">
          <div class="px-4 py-3 border-b border-base-300/50 flex items-center justify-between">
            <h2 class="font-mono text-xs text-muted uppercase tracking-wider">
              // Telegram Integration
            </h2>
            <div :if={@can_manage && @telegram_profile && !@telegram_editing} class="flex gap-2">
              <button
                phx-click="toggle_telegram_edit"
                class="btn-subtle flex items-center gap-1"
              >
                <.icon name="hero-pencil" class="size-3" />
                <span class="text-xs">Edit</span>
              </button>
              <button
                phx-click="delete_telegram"
                data-confirm="Remove Telegram integration? Telegram subscriptions will stop delivering."
                class="btn-subtle text-error/70 hover:text-error flex items-center gap-1"
              >
                <.icon name="hero-trash" class="size-3" />
                <span class="text-xs">Remove</span>
              </button>
            </div>
          </div>

          <%= if @telegram_profile && !@telegram_editing do %>
            <div class="p-4 space-y-3">
              <div class="flex items-center justify-between py-2 border-b border-base-300/30">
                <span class="text-xs text-muted">Bot Token</span>
                <span class="font-mono text-sm">
                  {GI.TelegramProfiles.TelegramProfile.mask_token(
                    @telegram_profile.bot_token_encrypted
                  )}
                </span>
              </div>
              <div class="flex items-center justify-between py-2">
                <span class="text-xs text-muted">Bot Username</span>
                <span class="font-mono text-sm">
                  {if @telegram_profile.bot_username,
                    do: "@#{@telegram_profile.bot_username}",
                    else: "—"}
                </span>
              </div>
            </div>
          <% else %>
            <div :if={@can_manage} class="p-4">
              <.form
                for={@telegram_changeset}
                phx-submit="save_telegram"
                class="space-y-4"
              >
                <div>
                  <label class="block text-xs text-muted mb-1">Bot Token *</label>
                  <input
                    type="password"
                    name="telegram_profile[bot_token]"
                    value=""
                    placeholder={
                      if @telegram_profile,
                        do: "Leave blank to keep current token",
                        else: "123456:ABC-DEF..."
                    }
                    autocomplete="off"
                    class="input-primary w-full"
                    required={!@telegram_profile}
                  />
                  <p class="font-mono text-[10px] text-muted mt-1">
                    Get from @BotFather on Telegram. Encrypted at rest.
                  </p>
                </div>
                <div>
                  <label class="block text-xs text-muted mb-1">Bot Username (optional)</label>
                  <input
                    type="text"
                    name="telegram_profile[bot_username]"
                    value={if @telegram_profile, do: @telegram_profile.bot_username, else: ""}
                    placeholder="@your_bot"
                    class="input-primary w-full"
                  />
                </div>
                <div class="flex items-center gap-2">
                  <button type="submit" class="btn-action flex items-center gap-2">
                    <.icon name="hero-check" class="size-4" />
                    <span>{if @telegram_profile, do: "Update", else: "Connect"}</span>
                  </button>
                  <button
                    :if={@telegram_editing}
                    type="button"
                    phx-click="toggle_telegram_edit"
                    class="btn-subtle"
                  >
                    Cancel
                  </button>
                </div>
              </.form>
            </div>
            <div
              :if={!@can_manage && !@telegram_profile}
              class="p-4 text-center"
            >
              <p class="font-mono text-xs text-muted">
                No Telegram integration configured. Contact an admin to set up.
              </p>
            </div>
          <% end %>
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
        title="Edit Account"
        on_cancel={JS.patch(~p"/dashboard/#{@account.slug}")}
      >
        <.live_component
          module={GIWeb.Dashboard.AccountLive.FormComponent}
          id={@account.id}
          action={:edit}
          account={@account}
          patch={~p"/dashboard/#{@account.slug}"}
        />
      </.modal>
    </GIWeb.Layouts.dashboard>
    """
  end
end
