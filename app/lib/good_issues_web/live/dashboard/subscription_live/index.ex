defmodule GIWeb.Dashboard.SubscriptionLive.Index do
  @moduledoc """
  Dashboard view for listing event subscriptions scoped to the current account.
  """
  use GIWeb, :live_view

  alias GI.Accounts.Scope
  alias GI.Notifications

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :can_manage, Scope.can_manage_account?(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    account = socket.assigns.current_scope.account
    subscriptions = Notifications.list_subscriptions(account_id: account.id)

    {:noreply,
     socket
     |> assign(:page_title, "Subscriptions")
     |> assign(:subscriptions, subscriptions)
     |> assign(:total, length(subscriptions))}
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    account = socket.assigns.current_scope.account

    with {:ok, sub} <- Notifications.get_subscription(id, account.id),
         {:ok, _sub} <- Notifications.update_subscription(sub, %{active: !sub.active}) do
      subscriptions = Notifications.list_subscriptions(account_id: account.id)
      {:noreply, assign(socket, :subscriptions, subscriptions)}
    else
      _ -> {:noreply, put_flash(socket, :error, "Failed to update subscription.")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    account = socket.assigns.current_scope.account

    with {:ok, sub} <- Notifications.get_subscription(id, account.id),
         {:ok, _sub} <- Notifications.delete_subscription(sub) do
      subscriptions = Notifications.list_subscriptions(account_id: account.id)

      {:noreply,
       socket
       |> put_flash(:info, "Subscription deleted.")
       |> assign(:subscriptions, subscriptions)
       |> assign(:total, length(subscriptions))}
    else
      _ -> {:noreply, put_flash(socket, :error, "Failed to delete subscription.")}
    end
  end

  defp channel_icon("email"), do: "hero-envelope"
  defp channel_icon("webhook"), do: "hero-globe-alt"
  defp channel_icon("telegram"), do: "hero-paper-airplane"
  defp channel_icon(_), do: "hero-bell"

  defp truncate_destination(nil), do: "—"

  defp truncate_destination(dest) when byte_size(dest) > 40 do
    String.slice(dest, 0, 37) <> "..."
  end

  defp truncate_destination(dest), do: dest

  @impl true
  def render(assigns) do
    ~H"""
    <GIWeb.Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      active_nav={:subscriptions}
    >
      <div class="h-full flex flex-col">
        <%!-- Page header --%>
        <div class="px-6 py-5 border-b border-base-300/50 bg-base-100">
          <div class="flex items-center justify-between mb-3">
            <div class="flex items-center gap-4">
              <div class="size-10 rounded-sm bg-primary/10 border border-primary/20 flex items-center justify-center">
                <.icon name="hero-bell" class="size-5 text-primary" />
              </div>
              <div>
                <h1 class="text-lg font-semibold text-base-content">Subscriptions</h1>
                <div class="font-mono text-xs text-muted mt-0.5">
                  {@total} subscriptions • {@current_scope.account.name}
                </div>
              </div>
            </div>
            <.link
              :if={@can_manage}
              navigate={~p"/dashboard/#{@current_scope.account.slug}/subscriptions/new"}
              class="btn-action flex items-center gap-2"
            >
              <.icon name="hero-plus" class="size-4" />
              <span>New Subscription</span>
            </.link>
          </div>
        </div>

        <%!-- List content --%>
        <div class="flex-1 overflow-auto px-2 sm:px-0">
          <%!-- Table header --%>
          <div :if={@total > 0} class="group-header sticky top-0 z-10 hidden sm:flex">
            <div class="flex items-center gap-2 flex-1">
              <span>// SUBSCRIPTIONS</span>
              <span class="opacity-60">
                [{length(Enum.filter(@subscriptions, & &1.active))} active]
              </span>
            </div>
            <div class="hidden sm:block w-48 text-right">DESTINATION</div>
            <div class="w-24 text-right">CHANNEL</div>
            <div class="hidden lg:block w-20 text-right">EVENTS</div>
            <div class="w-28"></div>
          </div>

          <%!-- Subscriptions list --%>
          <div id="subscriptions-list" class="animate-stagger space-y-2 sm:space-y-0">
            <%= for sub <- @subscriptions do %>
              <%!-- Mobile card --%>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/subscriptions/#{sub.id}"}
                class="sm:hidden block p-4 rounded-lg border border-base-300/50 bg-base-100"
                id={"sub-mobile-#{sub.id}"}
              >
                <div class="flex items-start justify-between gap-3 mb-3">
                  <div class="flex items-center gap-3 flex-1 min-w-0">
                    <div class={[
                      "size-2.5 rounded-full shrink-0",
                      sub.active && "bg-success shadow-[0_0_8px] shadow-success/50",
                      !sub.active && "bg-error/40"
                    ]}>
                    </div>
                    <div class="flex-1 min-w-0">
                      <span class={[
                        "font-medium block",
                        !sub.active && "opacity-40"
                      ]}>
                        {sub.name}
                      </span>
                      <span class="text-xs text-muted font-mono mt-1 block truncate">
                        {truncate_destination(sub.destination)}
                      </span>
                    </div>
                  </div>
                </div>
                <div class="flex items-center justify-between">
                  <span class={[
                    "status-badge",
                    sub.channel == "webhook" && "status-badge-pending",
                    sub.channel == "email" && "status-badge-active",
                    sub.channel == "telegram" && "status-badge-info"
                  ]}>
                    {String.upcase(sub.channel)}
                  </span>
                  <span class="text-xs text-muted font-mono">
                    {length(sub.event_types)} events
                  </span>
                </div>
              </.link>

              <%!-- Desktop row --%>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/subscriptions/#{sub.id}"}
                class="data-row group cursor-pointer hidden sm:flex"
                id={"sub-#{sub.id}"}
              >
                <%!-- Status indicator --%>
                <div class="w-8 flex justify-center">
                  <div class={[
                    "size-2.5 rounded-full",
                    sub.active && "bg-success shadow-[0_0_8px] shadow-success/50",
                    !sub.active && "bg-error/40"
                  ]}>
                  </div>
                </div>

                <%!-- Name --%>
                <div class="flex-1 min-w-0 flex items-center gap-3">
                  <.icon name={channel_icon(sub.channel)} class="size-4 text-muted" />
                  <span class={["font-medium", !sub.active && "opacity-40"]}>
                    {sub.name}
                  </span>
                </div>

                <%!-- Destination --%>
                <div class="hidden sm:block text-sm text-muted w-48 truncate text-right font-mono">
                  {truncate_destination(sub.destination)}
                </div>

                <%!-- Channel badge --%>
                <div class="w-24 flex justify-end">
                  <span class={[
                    "status-badge",
                    sub.channel == "webhook" && "status-badge-pending",
                    sub.channel == "email" && "status-badge-active",
                    sub.channel == "telegram" && "status-badge-info"
                  ]}>
                    {String.upcase(sub.channel)}
                  </span>
                </div>

                <%!-- Event count --%>
                <div class="hidden lg:block text-sm text-muted w-20 text-right font-mono">
                  {length(sub.event_types)}
                </div>

                <%!-- Actions --%>
                <div class="w-28 flex justify-end gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <%= if @can_manage do %>
                    <button
                      phx-click="toggle"
                      phx-value-id={sub.id}
                      class="p-2 rounded-sm hover:bg-base-200 text-muted hover:text-base-content transition-colors"
                      title={if sub.active, do: "Pause", else: "Activate"}
                      onclick="event.preventDefault(); event.stopPropagation();"
                    >
                      <.icon
                        name={if sub.active, do: "hero-pause", else: "hero-play"}
                        class="size-4"
                      />
                    </button>
                    <button
                      phx-click="delete"
                      phx-value-id={sub.id}
                      data-confirm="Are you sure you want to delete this subscription?"
                      class="p-2 rounded-sm hover:bg-error/15 text-error/60 hover:text-error transition-colors"
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
          <div :if={@total == 0} class="flex flex-col items-center justify-center py-20 text-muted">
            <div class="size-16 rounded-sm bg-base-200 border border-base-300 flex items-center justify-center mb-6">
              <.icon name="hero-bell" class="size-8 opacity-30" />
            </div>
            <div class="font-mono text-sm mb-2">$ goodissues subscriptions list</div>
            <div class="font-mono text-xs text-muted mb-6">No subscriptions found.</div>
            <.link
              :if={@can_manage}
              navigate={~p"/dashboard/#{@current_scope.account.slug}/subscriptions/new"}
              class="btn-action"
            >
              Create your first subscription
            </.link>
          </div>
        </div>

        <%!-- Info banner for read-only users --%>
        <div
          :if={!@can_manage}
          class="mx-6 mb-4 px-4 py-3 rounded-sm bg-info/10 border border-info/20 flex items-center gap-3"
        >
          <.icon name="hero-information-circle" class="size-5 text-info" />
          <span class="font-mono text-xs text-info">
            // READ-ONLY ACCESS — Contact an admin to manage subscriptions.
          </span>
        </div>
      </div>
    </GIWeb.Layouts.dashboard>
    """
  end
end
