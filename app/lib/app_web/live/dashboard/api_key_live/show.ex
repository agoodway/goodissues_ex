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

  defp relative_time(nil), do: nil

  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> nil
    end
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
      <style>
        @keyframes pulse-glow {
          0%, 100% { box-shadow: 0 0 0 0 oklch(80% 0.2 145 / 0.4); }
          50% { box-shadow: 0 0 12px 4px oklch(80% 0.2 145 / 0.15); }
        }
        @keyframes scan {
          0% { transform: translateY(-100%); }
          100% { transform: translateY(100%); }
        }
        .key-hero { position: relative; overflow: hidden; }
        .key-hero::before {
          content: '';
          position: absolute;
          inset: 0;
          background: linear-gradient(135deg, oklch(80% 0.18 145 / 0.06) 0%, transparent 50%, oklch(70% 0.12 45 / 0.04) 100%);
          pointer-events: none;
        }
        .key-hero::after {
          content: '';
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          height: 1px;
          background: linear-gradient(90deg, transparent, oklch(80% 0.18 145 / 0.5), transparent);
        }
        .status-indicator-active {
          animation: pulse-glow 2.5s ease-in-out infinite;
        }
        .data-panel {
          position: relative;
          background: oklch(7% 0.008 270);
          border: 1px solid oklch(15% 0.012 270);
        }
        .data-panel::before {
          content: '';
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          height: 2px;
          background: linear-gradient(90deg, oklch(80% 0.18 145 / 0.6), oklch(75% 0.15 200 / 0.4), transparent);
        }
        [data-theme="light"] .data-panel {
          background: oklch(99% 0.003 90);
          border-color: oklch(88% 0.01 90);
        }
        [data-theme="light"] .data-panel::before {
          background: linear-gradient(90deg, oklch(50% 0.2 145 / 0.5), oklch(50% 0.18 200 / 0.3), transparent);
        }
        .field-row {
          display: grid;
          grid-template-columns: 110px 1fr;
          gap: 0.75rem;
          padding: 0.625rem 0;
          border-bottom: 1px solid oklch(12% 0.01 270);
          align-items: baseline;
        }
        @media (min-width: 640px) {
          .field-row {
            grid-template-columns: 140px 1fr;
            gap: 1rem;
          }
        }
        .field-row:last-child { border-bottom: none; }
        [data-theme="light"] .field-row {
          border-bottom-color: oklch(92% 0.008 90);
        }
        .field-label {
          font-family: 'JetBrains Mono', monospace;
          font-size: 0.6875rem;
          font-weight: 600;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: oklch(50% 0.01 270);
        }
        [data-theme="light"] .field-label {
          color: oklch(45% 0.01 270);
        }
        .field-value {
          font-size: 0.8125rem;
          color: oklch(88% 0.01 270);
          word-break: break-all;
        }
        [data-theme="light"] .field-value {
          color: oklch(25% 0.01 270);
        }
        .token-display {
          font-family: 'JetBrains Mono', monospace;
          font-size: 0.75rem;
          background: oklch(10% 0.01 270);
          border: 1px solid oklch(18% 0.012 270);
          padding: 0.5rem 0.625rem;
          letter-spacing: 0.05em;
          color: oklch(80% 0.18 145);
          display: inline-flex;
          align-items: center;
          gap: 0.375rem;
          flex-wrap: wrap;
        }
        @media (min-width: 640px) {
          .token-display {
            font-size: 0.875rem;
            padding: 0.5rem 0.75rem;
            gap: 0.5rem;
          }
        }
        [data-theme="light"] .token-display {
          background: oklch(96% 0.006 90);
          border-color: oklch(88% 0.01 90);
          color: oklch(45% 0.2 145);
        }
        .scope-chip {
          display: inline-flex;
          align-items: center;
          gap: 0.25rem;
          padding: 0.3125rem 0.5rem;
          font-family: 'JetBrains Mono', monospace;
          font-size: 0.625rem;
          font-weight: 500;
          background: oklch(15% 0.01 270);
          border: 1px solid oklch(20% 0.012 270);
          color: oklch(70% 0.01 270);
          margin: 0.125rem;
        }
        @media (min-width: 640px) {
          .scope-chip {
            font-size: 0.6875rem;
            padding: 0.25rem 0.5rem;
          }
        }
        [data-theme="light"] .scope-chip {
          background: oklch(94% 0.006 90);
          border-color: oklch(88% 0.01 90);
          color: oklch(40% 0.01 270);
        }
        .scope-chip.scope-read {
          border-color: oklch(70% 0.15 240 / 0.4);
          color: oklch(70% 0.15 240);
        }
        .scope-chip.scope-write {
          border-color: oklch(85% 0.18 85 / 0.4);
          color: oklch(85% 0.18 85);
        }
        [data-theme="light"] .scope-chip.scope-read {
          border-color: oklch(50% 0.18 240 / 0.4);
          color: oklch(45% 0.18 240);
        }
        [data-theme="light"] .scope-chip.scope-write {
          border-color: oklch(55% 0.2 85 / 0.4);
          color: oklch(45% 0.2 85);
        }
        .timeline-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: oklch(30% 0.01 270);
          border: 2px solid oklch(20% 0.01 270);
          flex-shrink: 0;
        }
        .timeline-dot.active {
          background: oklch(80% 0.2 145);
          border-color: oklch(80% 0.2 145 / 0.4);
        }
        [data-theme="light"] .timeline-dot {
          background: oklch(75% 0.01 270);
          border-color: oklch(88% 0.01 90);
        }
        [data-theme="light"] .timeline-dot.active {
          background: oklch(50% 0.2 145);
          border-color: oklch(50% 0.2 145 / 0.3);
        }
        .timeline-line {
          width: 2px;
          background: oklch(15% 0.01 270);
          margin-left: 3px;
        }
        [data-theme="light"] .timeline-line {
          background: oklch(90% 0.008 90);
        }
      </style>

      <%!-- Navigation breadcrumb --%>
      <div class="flex items-center gap-2 mb-6 text-sm">
        <.link
          navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys"}
          class="text-muted hover:text-base-content transition-colors flex items-center gap-1.5"
        >
          <.icon name="hero-key" class="size-4" />
          <span>API Keys</span>
        </.link>
        <span class="text-muted">/</span>
        <span class="font-mono text-xs">{@api_key.name}</span>
      </div>

      <%!-- Hero Section --%>
      <div class="key-hero data-panel p-4 sm:p-6 mb-4 sm:mb-6">
        <div class="flex flex-col lg:flex-row lg:items-start lg:justify-between gap-4 sm:gap-6">
          <%!-- Left: Key Identity --%>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-3 mb-3 sm:mb-4">
              <div class={[
                "w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center text-lg font-bold flex-shrink-0",
                @api_key.status == :active && "bg-success/15 text-success status-indicator-active",
                @api_key.status == :revoked && "bg-error/15 text-error"
              ]}>
                <.icon name={if @api_key.type == :private, do: "hero-lock-closed", else: "hero-globe-alt"} class="size-4 sm:size-5" />
              </div>
              <div class="min-w-0">
                <h1 class="text-lg sm:text-xl font-semibold tracking-tight truncate">{@api_key.name}</h1>
                <div class="flex items-center gap-2 mt-1 flex-wrap">
                  <span class={[
                    "status-badge",
                    @api_key.status == :active && "status-badge-active",
                    @api_key.status == :revoked && "status-badge-revoked"
                  ]}>
                    <%= if @api_key.status == :active do %>
                      <span class="inline-block w-1.5 h-1.5 rounded-full bg-current mr-1.5 animate-pulse"></span>
                    <% end %>
                    {@api_key.status}
                  </span>
                  <span class={[
                    "status-badge",
                    @api_key.type == :private && "status-badge-pending",
                    @api_key.type == :public && "status-badge-info"
                  ]}>
                    {@api_key.type}
                  </span>
                </div>
              </div>
            </div>

            <%!-- Token Display --%>
            <div class="token-display">
              <span class="opacity-60">$</span>
              <span>{@api_key.token_prefix}...</span>
              <span class="text-xs opacity-40 sm:ml-2">
                {if @api_key.type == :private, do: "secret key", else: "public key"}
              </span>
            </div>
          </div>

          <%!-- Right: Actions --%>
          <%= if @can_manage && @api_key.status == :active do %>
            <div class="flex gap-2 sm:flex-wrap lg:flex-col lg:items-end">
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/#{@api_key.id}/edit"}
                class="btn-subtle flex-1 sm:flex-none flex items-center justify-center gap-1.5 min-h-[2.5rem]"
              >
                <.icon name="hero-pencil-square" class="size-3.5" />
                <span>Edit Scopes</span>
              </.link>
              <button
                phx-click="revoke"
                data-confirm="Are you sure you want to revoke this API key? This action cannot be undone and any applications using this key will stop working immediately."
                class="btn-subtle flex-1 sm:flex-none flex items-center justify-center gap-1.5 min-h-[2.5rem] hover:!border-error/50 hover:!text-error hover:!bg-error/10 transition-colors"
              >
                <.icon name="hero-no-symbol" class="size-3.5" />
                <span>Revoke Key</span>
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Main Content Grid --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-3 sm:gap-4">
        <%!-- Scopes Panel - Full Width --%>
        <div class="lg:col-span-2 data-panel p-4 sm:p-5">
          <div class="flex items-center justify-between mb-3 sm:mb-4">
            <h2 class="font-mono text-xs font-semibold uppercase tracking-wider text-muted">
              Authorized Scopes
            </h2>
            <span class="font-mono text-xs text-muted">
              {length(@api_key.scopes)} permissions
            </span>
          </div>
          <div class="flex flex-wrap gap-1">
            <%= if @api_key.scopes == [] do %>
              <span class="scope-chip">
                <.icon name="hero-check-circle" class="size-3" />
                All scopes
              </span>
            <% else %>
              <%= for scope <- @api_key.scopes do %>
                <span class={[
                  "scope-chip",
                  String.contains?(scope, "read") && "scope-read",
                  String.contains?(scope, "write") && "scope-write"
                ]}>
                  <%= if String.contains?(scope, "read") do %>
                    <.icon name="hero-eye" class="size-3" />
                  <% else %>
                    <.icon name="hero-pencil" class="size-3" />
                  <% end %>
                  {scope}
                </span>
              <% end %>
            <% end %>
          </div>
        </div>

        <%!-- Activity Timeline Panel --%>
        <div class="data-panel p-4 sm:p-5">
          <h2 class="font-mono text-xs font-semibold uppercase tracking-wider text-muted mb-3 sm:mb-4">
            Activity
          </h2>
          <div class="space-y-0">
            <%!-- Created --%>
            <div class="flex gap-3">
              <div class="flex flex-col items-center">
                <div class="timeline-dot active"></div>
                <div class="timeline-line flex-1 min-h-6"></div>
              </div>
              <div class="pb-4">
                <div class="text-xs font-medium">Created</div>
                <div class="font-mono text-xs text-muted">{format_datetime(@api_key.inserted_at)}</div>
              </div>
            </div>

            <%!-- Last Used --%>
            <div class="flex gap-3">
              <div class="flex flex-col items-center">
                <div class={["timeline-dot", @api_key.last_used_at && "active"]}></div>
                <div class="timeline-line flex-1 min-h-6"></div>
              </div>
              <div class="pb-4">
                <div class="text-xs font-medium">Last Used</div>
                <%= if @api_key.last_used_at do %>
                  <div class="font-mono text-xs text-muted">
                    {format_datetime(@api_key.last_used_at)}
                  </div>
                  <%= if rel = relative_time(@api_key.last_used_at) do %>
                    <div class="text-xs text-success mt-0.5">{rel}</div>
                  <% end %>
                <% else %>
                  <div class="font-mono text-xs text-muted">Never</div>
                <% end %>
              </div>
            </div>

            <%!-- Updated --%>
            <div class="flex gap-3">
              <div class="flex flex-col items-center">
                <div class="timeline-dot active"></div>
                <div class="timeline-line flex-1 min-h-6"></div>
              </div>
              <div class="pb-4">
                <div class="text-xs font-medium">Last Updated</div>
                <div class="font-mono text-xs text-muted">{format_datetime(@api_key.updated_at)}</div>
              </div>
            </div>

            <%!-- Expires --%>
            <div class="flex gap-3">
              <div class="flex flex-col items-center">
                <div class={["timeline-dot", @api_key.expires_at && "active"]}></div>
              </div>
              <div>
                <div class="text-xs font-medium">Expires</div>
                <%= if @api_key.expires_at do %>
                  <div class="font-mono text-xs text-muted">{format_datetime(@api_key.expires_at)}</div>
                <% else %>
                  <div class="font-mono text-xs text-muted">Never</div>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <%!-- Key Details Panel --%>
        <div class="data-panel p-4 sm:p-5">
          <h2 class="font-mono text-xs font-semibold uppercase tracking-wider text-muted mb-3 sm:mb-4">
            Key Details
          </h2>
          <div class="space-y-0">
            <div class="field-row">
              <span class="field-label">ID</span>
              <span class="field-value font-mono text-xs opacity-70">{@api_key.id}</span>
            </div>
            <div class="field-row">
              <span class="field-label">Name</span>
              <span class="field-value">{@api_key.name}</span>
            </div>
            <div class="field-row">
              <span class="field-label">Type</span>
              <span class="field-value capitalize">{@api_key.type}</span>
            </div>
            <div class="field-row">
              <span class="field-label">Status</span>
              <span class="field-value capitalize">{@api_key.status}</span>
            </div>
          </div>
        </div>

        <%!-- Owner Panel --%>
        <div class="lg:col-span-2 data-panel p-4 sm:p-5">
          <h2 class="font-mono text-xs font-semibold uppercase tracking-wider text-muted mb-3 sm:mb-4">
            Owner Information
          </h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-x-6 sm:gap-x-8">
            <div class="field-row">
              <span class="field-label">User</span>
              <span class="field-value">{@api_key.account_user.user.email}</span>
            </div>
            <div class="field-row">
              <span class="field-label">Role</span>
              <span class={[
                "status-badge",
                @api_key.account_user.role == :owner && "status-badge-active",
                @api_key.account_user.role == :admin && "status-badge-pending",
                @api_key.account_user.role == :member && "status-badge-muted"
              ]}>
                {@api_key.account_user.role}
              </span>
            </div>
            <div class="field-row">
              <span class="field-label">Account</span>
              <span class="field-value">{@api_key.account_user.account.name}</span>
            </div>
            <div class="field-row">
              <span class="field-label">Slug</span>
              <span class="field-value font-mono text-xs">{@api_key.account_user.account.slug}</span>
            </div>
          </div>
        </div>
      </div>

      <%!-- Read-only Notice --%>
      <div :if={!@can_manage} class="mt-6 data-panel p-4 border-l-2 border-l-info">
        <div class="flex items-center gap-3">
          <.icon name="hero-information-circle" class="size-5 text-info flex-shrink-0" />
          <div>
            <div class="text-sm font-medium">Read-only Access</div>
            <div class="text-xs text-muted mt-0.5">Contact an account admin to modify or revoke this API key.</div>
          </div>
        </div>
      </div>

      <%!-- Back Link --%>
      <div class="mt-8 pt-6 border-t border-base-300">
        <.link
          navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys"}
          class="inline-flex items-center gap-2 text-sm text-muted hover:text-base-content transition-colors"
        >
          <.icon name="hero-arrow-left" class="size-4" />
          <span>Back to API Keys</span>
        </.link>
      </div>
    </FFWeb.Layouts.dashboard>
    """
  end
end
