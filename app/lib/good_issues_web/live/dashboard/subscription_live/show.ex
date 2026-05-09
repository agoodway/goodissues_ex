defmodule GIWeb.Dashboard.SubscriptionLive.Show do
  @moduledoc """
  Dashboard view for showing a single event subscription with notification log.
  """
  use GIWeb, :live_view

  alias GI.Accounts.Scope
  alias GI.Notifications

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :can_manage, Scope.can_manage_account?(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    account = socket.assigns.current_scope.account

    case Notifications.get_subscription(id, account.id) do
      {:ok, sub} ->
        logs =
          Notifications.list_notification_logs(account_id: account.id)
          |> Enum.filter(&(&1.subscription_id == sub.id))

        {:noreply,
         socket
         |> assign(:page_title, sub.name)
         |> assign(:subscription, sub)
         |> assign(:logs, logs)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Subscription not found.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/subscriptions")}
    end
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    sub = socket.assigns.subscription

    case Notifications.update_subscription(sub, %{active: !sub.active}) do
      {:ok, updated} ->
        {:noreply, assign(socket, :subscription, updated)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update subscription.")}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    sub = socket.assigns.subscription
    account_slug = socket.assigns.current_scope.account.slug

    case Notifications.delete_subscription(sub) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Subscription deleted.")
         |> push_navigate(to: ~p"/dashboard/#{account_slug}/subscriptions")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete subscription.")}
    end
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp humanize_event_type(type) do
    type
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp status_class("delivered"), do: "status-badge-active"
  defp status_class("failed"), do: "status-badge-revoked"
  defp status_class("pending"), do: "status-badge-pending"
  defp status_class(_), do: "status-badge-muted"

  @impl true
  def render(assigns) do
    ~H"""
    <GIWeb.Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      active_nav={:subscriptions}
    >
      <style>
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
      </style>

      <%!-- Breadcrumb --%>
      <div class="flex items-center gap-2 mb-6 text-sm">
        <.link
          navigate={~p"/dashboard/#{@current_scope.account.slug}/subscriptions"}
          class="text-muted hover:text-base-content transition-colors flex items-center gap-1.5"
        >
          <.icon name="hero-bell" class="size-4" />
          <span>Subscriptions</span>
        </.link>
        <span class="text-muted">/</span>
        <span class="font-mono text-xs">{@subscription.name}</span>
      </div>

      <%!-- Hero --%>
      <div class="data-panel p-4 sm:p-6 mb-4 sm:mb-6">
        <div class="flex flex-col lg:flex-row lg:items-start lg:justify-between gap-4 sm:gap-6">
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-3 mb-3">
              <div class={[
                "w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center flex-shrink-0",
                @subscription.active && "bg-success/15 text-success",
                !@subscription.active && "bg-error/15 text-error"
              ]}>
                <.icon
                  name={
                    if @subscription.channel == "webhook", do: "hero-globe-alt", else: "hero-envelope"
                  }
                  class="size-4 sm:size-5"
                />
              </div>
              <div class="min-w-0">
                <h1 class="text-lg sm:text-xl font-semibold tracking-tight truncate">
                  {@subscription.name}
                </h1>
                <div class="flex items-center gap-2 mt-1 flex-wrap">
                  <span class={[
                    "status-badge",
                    @subscription.active && "status-badge-active",
                    !@subscription.active && "status-badge-revoked"
                  ]}>
                    <%= if @subscription.active do %>
                      <span class="inline-block w-1.5 h-1.5 rounded-full bg-current mr-1.5 animate-pulse">
                      </span>
                    <% end %>
                    {if @subscription.active, do: "ACTIVE", else: "PAUSED"}
                  </span>
                  <span class="status-badge status-badge-info">
                    {String.upcase(@subscription.channel)}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <%= if @can_manage do %>
            <div class="flex gap-2">
              <button
                phx-click="toggle"
                class="btn-subtle flex items-center gap-1.5 min-h-[2.5rem]"
              >
                <.icon
                  name={if @subscription.active, do: "hero-pause", else: "hero-play"}
                  class="size-3.5"
                />
                <span>{if @subscription.active, do: "Pause", else: "Activate"}</span>
              </button>
              <button
                phx-click="delete"
                data-confirm="Are you sure you want to delete this subscription? This action cannot be undone."
                class="btn-subtle flex items-center gap-1.5 min-h-[2.5rem] hover:!border-error/50 hover:!text-error hover:!bg-error/10 transition-colors"
              >
                <.icon name="hero-trash" class="size-3.5" />
                <span>Delete</span>
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Content Grid --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-3 sm:gap-4">
        <%!-- Details Panel --%>
        <div class="data-panel p-4 sm:p-5">
          <h2 class="font-mono text-xs font-semibold uppercase tracking-wider text-muted mb-3 sm:mb-4">
            Details
          </h2>
          <div class="space-y-0">
            <div class="field-row">
              <span class="field-label">Channel</span>
              <span class="field-value capitalize">{@subscription.channel}</span>
            </div>
            <div class="field-row">
              <span class="field-label">Destination</span>
              <span class="field-value font-mono text-xs">{@subscription.destination}</span>
            </div>
            <div :if={@subscription.user} class="field-row">
              <span class="field-label">User</span>
              <span class="field-value">{@subscription.user.email}</span>
            </div>
            <div class="field-row">
              <span class="field-label">Created</span>
              <span class="field-value font-mono text-xs">
                {format_datetime(@subscription.inserted_at)}
              </span>
            </div>
            <div :if={@subscription.channel == "webhook"} class="field-row">
              <span class="field-label">Secret</span>
              <span class="field-value font-mono text-xs opacity-60">
                {String.slice(@subscription.secret || "", 0, 12)}...
              </span>
            </div>
          </div>
        </div>

        <%!-- Event Types Panel --%>
        <div class="data-panel p-4 sm:p-5">
          <h2 class="font-mono text-xs font-semibold uppercase tracking-wider text-muted mb-3 sm:mb-4">
            Event Types
          </h2>
          <div class="flex flex-wrap gap-1.5">
            <%= for type <- @subscription.event_types do %>
              <span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-sm text-xs font-mono border border-base-300/50 bg-base-200/50">
                {humanize_event_type(type)}
              </span>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Notification Log --%>
      <div class="mt-4 data-panel p-4 sm:p-5">
        <h2 class="font-mono text-xs font-semibold uppercase tracking-wider text-muted mb-3 sm:mb-4">
          Delivery Log <span class="opacity-60 ml-2">[{length(@logs)} entries]</span>
        </h2>

        <%= if @logs == [] do %>
          <div class="text-center py-8 text-muted">
            <div class="font-mono text-xs">No deliveries yet.</div>
          </div>
        <% else %>
          <div class="space-y-0">
            <%!-- Header --%>
            <div class="group-header hidden sm:flex text-xs">
              <div class="w-16">STATUS</div>
              <div class="flex-1">EVENT</div>
              <div class="w-48">DESTINATION</div>
              <div class="w-40 text-right">TIMESTAMP</div>
            </div>

            <%= for log <- @logs do %>
              <div class="data-row flex flex-col sm:flex-row sm:items-center gap-1 sm:gap-0">
                <div class="w-16">
                  <span class={["status-badge", status_class(log.status)]}>
                    {String.upcase(log.status)}
                  </span>
                </div>
                <div class="flex-1 font-mono text-xs">
                  {humanize_event_type(log.event_type)}
                </div>
                <div class="w-48 font-mono text-xs text-muted truncate">
                  {log.destination}
                </div>
                <div class="w-40 text-right font-mono text-xs text-muted">
                  {format_datetime(log.inserted_at)}
                </div>
              </div>
              <div :if={log.error} class="px-4 py-1.5 text-xs text-error font-mono bg-error/5">
                {log.error}
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <%!-- Back Link --%>
      <div class="mt-8 pt-6 border-t border-base-300">
        <.link
          navigate={~p"/dashboard/#{@current_scope.account.slug}/subscriptions"}
          class="inline-flex items-center gap-2 text-sm text-muted hover:text-base-content transition-colors"
        >
          <.icon name="hero-arrow-left" class="size-4" />
          <span>Back to Subscriptions</span>
        </.link>
      </div>
    </GIWeb.Layouts.dashboard>
    """
  end
end
