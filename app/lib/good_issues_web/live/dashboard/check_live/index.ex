defmodule FFWeb.Dashboard.CheckLive.Index do
  @moduledoc """
  Dashboard view for listing uptime checks scoped to a project.

  Shows a realtime status board with PubSub-driven live updates.
  """
  use FFWeb, :live_view

  alias FF.Accounts.Scope
  alias FF.Monitoring
  alias FF.Tracking

  @impl true
  def mount(%{"project_id" => project_id}, _session, socket) do
    account = socket.assigns.current_scope.account

    case Tracking.get_project(account, project_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Project not found.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects")}

      project ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(FF.PubSub, Monitoring.checks_topic(project.id))
        end

        can_manage = Scope.can_manage_account?(socket.assigns.current_scope)

        {:ok,
         socket
         |> assign(:project, project)
         |> assign(:can_manage, can_manage)
         |> assign(:page_title, "Checks")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    account = socket.assigns.current_scope.account
    project = socket.assigns.project
    page = parse_page_param(params["page"])

    result = Monitoring.list_checks(account, project.id, %{page: page})

    socket
    |> assign(:checks, result.checks)
    |> assign(:page, result.page)
    |> assign(:per_page, result.per_page)
    |> assign(:total_pages, result.total_pages)
    |> assign(:total, result.total)
  end

  defp parse_page_param(nil), do: 1

  defp parse_page_param(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> 1
    end
  end

  defp parse_page_param(_), do: 1

  defp pagination_path(account_slug, project_id, page) do
    params = if page > 1, do: %{page: page}, else: %{}
    ~p"/dashboard/#{account_slug}/projects/#{project_id}/checks?#{params}"
  end

  # Pause/resume toggle
  @impl true
  def handle_event("toggle_pause", %{"id" => check_id}, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      account = socket.assigns.current_scope.account
      project = socket.assigns.project

      case Monitoring.get_check(account, project.id, check_id) do
        nil ->
          {:noreply, put_flash(socket, :error, "Check not found.")}

        check ->
          case Monitoring.update_check(check, %{paused: !check.paused}) do
            {:ok, _updated} ->
              {:noreply, socket}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Failed to update check.")}
          end
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission.")}
    end
  end

  # PubSub handlers
  @impl true
  def handle_info({:check_created, payload}, socket) do
    checks = socket.assigns.checks ++ [struct(FF.Monitoring.Check, payload)]
    {:noreply, assign(socket, checks: checks, total: socket.assigns.total + 1)}
  end

  @impl true
  def handle_info({:check_updated, payload}, socket) do
    checks =
      Enum.map(socket.assigns.checks, fn check ->
        if check.id == payload.id, do: struct(check, payload), else: check
      end)

    {:noreply, assign(socket, :checks, checks)}
  end

  @impl true
  def handle_info({:check_deleted, %{id: id}}, socket) do
    checks = Enum.reject(socket.assigns.checks, &(&1.id == id))
    {:noreply, assign(socket, checks: checks, total: max(socket.assigns.total - 1, 0))}
  end

  @impl true
  def handle_info({:check_run_completed, payload}, socket) do
    checks =
      Enum.map(socket.assigns.checks, fn check ->
        if check.id == payload.id, do: struct(check, payload), else: check
      end)

    {:noreply, assign(socket, :checks, checks)}
  end

  defp status_indicator(:up), do: {"bg-success", "UP"}
  defp status_indicator(:down), do: {"bg-error", "DOWN"}
  defp status_indicator(:unknown), do: {"bg-base-content/30", "UNKNOWN"}

  defp method_label(method), do: method |> to_string() |> String.upcase()

  defp format_interval(seconds) when seconds < 60, do: "#{seconds}s"
  defp format_interval(seconds) when rem(seconds, 60) == 0, do: "#{div(seconds, 60)}m"
  defp format_interval(seconds), do: "#{div(seconds, 60)}m #{rem(seconds, 60)}s"

  defp format_relative_time(nil), do: "Never"

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86_400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <FFWeb.Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      active_nav={:projects}
    >
      <div class="h-full flex flex-col">
        <%!-- Page header --%>
        <div class="px-4 sm:px-6 py-4 sm:py-5 border-b border-base-300/50 bg-base-100">
          <div class="flex items-center gap-2 mb-3">
            <.link
              navigate={~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}"}
              class="text-muted hover:text-base-content transition-colors group flex items-center gap-1"
            >
              <.icon
                name="hero-arrow-left"
                class="size-4 group-hover:-translate-x-0.5 transition-transform"
              />
              <span class="font-mono text-xs">Projects</span>
            </.link>
            <span class="text-base-content/20 font-mono">/</span>
            <span class="font-mono text-xs text-base-content/50">{@project.prefix}</span>
            <span class="text-base-content/20 font-mono">/</span>
            <span class="font-mono text-xs text-base-content/50">Checks</span>
          </div>

          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3 sm:gap-4">
              <div class="size-9 sm:size-10 rounded-sm bg-primary/10 border border-primary/20 flex items-center justify-center">
                <.icon name="hero-signal" class="size-4 sm:size-5 text-primary" />
              </div>
              <div>
                <h1 class="text-base sm:text-lg font-semibold text-base-content">Uptime Checks</h1>
                <div class="font-mono text-[11px] sm:text-xs text-muted mt-0.5">
                  {@total} check{if @total != 1, do: "s", else: ""} &middot; {@project.name}
                </div>
              </div>
            </div>

            <.link
              :if={@can_manage}
              navigate={
                ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks/new"
              }
              class="btn-primary py-2 px-3 font-mono text-xs"
            >
              <.icon name="hero-plus" class="size-3.5 mr-1" /> New Check
            </.link>
          </div>
        </div>

        <%!-- List content --%>
        <div class="flex-1 overflow-auto px-2 sm:px-4">
          <%!-- Table header (hidden on mobile) --%>
          <div :if={@total > 0} class="group-header sticky top-0 z-10 !gap-0 hidden sm:flex">
            <div class="w-8 shrink-0"></div>
            <div class="flex-1 min-w-0 mr-4">NAME</div>
            <div class="w-48 shrink-0 mr-4 hidden lg:block">URL</div>
            <div class="w-14 shrink-0 mr-4">METHOD</div>
            <div class="w-16 shrink-0 mr-4">INTERVAL</div>
            <div class="w-20 shrink-0 mr-4">LAST RUN</div>
            <div :if={@can_manage} class="w-20 shrink-0"></div>
          </div>

          <%!-- Checks list --%>
          <div id="checks-list" class="animate-stagger space-y-2 sm:space-y-0 pt-3 sm:pt-0">
            <%= for check <- @checks do %>
              <%!-- Mobile card layout --%>
              <div
                class="sm:hidden p-4 rounded-lg border border-base-300/50 bg-base-100 block"
                id={"check-mobile-#{check.id}"}
              >
                <.link
                  navigate={
                    ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks/#{check.id}"
                  }
                  class="block"
                >
                  <div class="flex items-start justify-between gap-3 mb-3">
                    <div class="flex items-center gap-2">
                      <%= if check.paused do %>
                        <span class="status-badge status-badge-muted">PAUSED</span>
                      <% else %>
                        <% {color, label} = status_indicator(check.status) %>
                        <span class={["size-2.5 rounded-full", color]}></span>
                        <span class="font-mono text-xs text-muted">{label}</span>
                      <% end %>
                    </div>
                    <span class="font-mono text-xs text-muted">
                      {method_label(check.method)}
                    </span>
                  </div>
                  <div class="font-medium mb-1">{check.name}</div>
                  <div class="font-mono text-xs text-muted truncate mb-2">{check.url}</div>
                  <div class="flex items-center justify-between text-xs text-muted font-mono">
                    <span>Every {format_interval(check.interval_seconds)}</span>
                    <span>{format_relative_time(check.last_checked_at)}</span>
                  </div>
                </.link>
                <div :if={@can_manage} class="mt-3 pt-3 border-t border-base-300/30">
                  <button
                    phx-click="toggle_pause"
                    phx-value-id={check.id}
                    class="btn-subtle py-1 px-2 font-mono text-xs"
                  >
                    <%= if check.paused do %>
                      <.icon name="hero-play" class="size-3.5 mr-1" /> Resume
                    <% else %>
                      <.icon name="hero-pause" class="size-3.5 mr-1" /> Pause
                    <% end %>
                  </button>
                </div>
              </div>

              <%!-- Desktop row layout --%>
              <div
                class={[
                  "data-row group hidden sm:flex cursor-pointer items-center",
                  check.paused && "opacity-50"
                ]}
                id={"check-#{check.id}"}
              >
                <%!-- Status indicator --%>
                <div class="w-8 shrink-0 flex justify-center">
                  <%= if check.paused do %>
                    <span class="status-badge status-badge-muted text-[10px]">P</span>
                  <% else %>
                    <% {color, _label} = status_indicator(check.status) %>
                    <span class={["size-2.5 rounded-full", color]}></span>
                  <% end %>
                </div>

                <%!-- Name (clickable) --%>
                <.link
                  navigate={
                    ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks/#{check.id}"
                  }
                  class="flex-1 min-w-0 mr-4"
                >
                  <span class="font-medium truncate block group-hover:text-primary transition-colors">
                    {check.name}
                  </span>
                </.link>

                <%!-- URL --%>
                <div class="w-48 shrink-0 mr-4 hidden lg:block">
                  <span class="font-mono text-xs text-muted truncate block">{check.url}</span>
                </div>

                <%!-- Method badge --%>
                <div class="w-14 shrink-0 mr-4">
                  <span class="status-badge status-badge-info">{method_label(check.method)}</span>
                </div>

                <%!-- Interval --%>
                <div class="w-16 shrink-0 mr-4">
                  <span class="font-mono text-xs text-muted">
                    {format_interval(check.interval_seconds)}
                  </span>
                </div>

                <%!-- Last checked --%>
                <div class="w-20 shrink-0 mr-4">
                  <span class="font-mono text-xs text-muted">
                    {format_relative_time(check.last_checked_at)}
                  </span>
                </div>

                <%!-- Pause/Resume button --%>
                <div :if={@can_manage} class="w-20 shrink-0 flex justify-end">
                  <button
                    phx-click="toggle_pause"
                    phx-value-id={check.id}
                    class="btn-subtle py-1 px-2 font-mono text-xs opacity-0 group-hover:opacity-100 transition-opacity"
                  >
                    <%= if check.paused do %>
                      Resume
                    <% else %>
                      Pause
                    <% end %>
                  </button>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Empty state --%>
          <div :if={@total == 0} class="flex flex-col items-center justify-center py-20 text-muted">
            <div class="size-16 rounded-sm bg-base-200 border border-base-300 flex items-center justify-center mb-6">
              <.icon name="hero-signal" class="size-8 opacity-30" />
            </div>
            <div class="font-mono text-sm mb-2">$ fruitfly checks list</div>
            <div class="font-mono text-xs text-muted mb-6">No uptime checks configured.</div>
            <.link
              :if={@can_manage}
              navigate={
                ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks/new"
              }
              class="btn-primary py-2 px-4 font-mono text-sm"
            >
              <.icon name="hero-plus" class="size-4 mr-1" /> Create first check
            </.link>
          </div>
        </div>

        <%!-- Footer with pagination --%>
        <div
          :if={@total > 0}
          class="px-6 py-3 border-t border-base-300/50 flex items-center justify-between bg-base-100"
        >
          <span class="font-mono text-xs text-muted">
            [{@page * @per_page - @per_page + 1}-{min(@page * @per_page, @total)}] of {@total}
          </span>

          <div :if={@total_pages > 1} class="flex items-center gap-2">
            <.link
              :if={@page > 1}
              patch={pagination_path(@current_scope.account.slug, @project.id, @page - 1)}
              class="btn-subtle py-1.5 px-3 font-mono text-xs"
            >
              <.icon name="hero-chevron-left" class="size-3.5" />
            </.link>
            <span class="font-mono text-xs text-muted px-2">
              {@page}/{@total_pages}
            </span>
            <.link
              :if={@page < @total_pages}
              patch={pagination_path(@current_scope.account.slug, @project.id, @page + 1)}
              class="btn-subtle py-1.5 px-3 font-mono text-xs"
            >
              <.icon name="hero-chevron-right" class="size-3.5" />
            </.link>
          </div>
        </div>
      </div>
    </FFWeb.Layouts.dashboard>
    """
  end
end
