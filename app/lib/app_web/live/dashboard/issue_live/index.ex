defmodule FFWeb.Dashboard.IssueLive.Index do
  @moduledoc """
  Dashboard view for listing issues scoped to the current account.

  Shows all issues belonging to the current account's projects, with filtering
  and pagination. Matches the industrial terminal aesthetic from the API Keys UI.
  """
  use FFWeb, :live_view

  alias FF.Tracking
  alias FF.Accounts.Scope

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :can_manage, Scope.can_manage_account?(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    account = socket.assigns.current_scope.account
    page = parse_page_param(params["page"])
    status = params["status"] || ""
    type = params["type"] || ""

    filters =
      %{page: page}
      |> maybe_add_filter(:status, status)
      |> maybe_add_filter(:type, type)

    result = Tracking.list_issues_paginated(account, filters)

    socket
    |> assign(:page_title, "Issues")
    |> assign(:issues, result.issues)
    |> assign(:page, result.page)
    |> assign(:per_page, result.per_page)
    |> assign(:total_pages, result.total_pages)
    |> assign(:total, result.total)
    |> assign(:status_filter, status)
    |> assign(:type_filter, type)
  end

  defp parse_page_param(nil), do: 1

  defp parse_page_param(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> 1
    end
  end

  defp parse_page_param(_), do: 1

  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp pagination_path(account_slug, status, type, page) do
    params =
      %{status: status, type: type, page: page}
      |> Enum.reject(fn {_k, v} -> v == "" or v == 1 end)

    ~p"/dashboard/#{account_slug}/issues?#{params}"
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    account_slug = socket.assigns.current_scope.account.slug

    {:noreply,
     push_patch(socket,
       to: pagination_path(account_slug, status, socket.assigns.type_filter, 1)
     )}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    account_slug = socket.assigns.current_scope.account.slug

    {:noreply,
     push_patch(socket,
       to: pagination_path(account_slug, socket.assigns.status_filter, type, 1)
     )}
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end

  defp status_class(:new), do: "status-badge-info"
  defp status_class(:in_progress), do: "status-badge-pending"
  defp status_class(:archived), do: "status-badge-muted"

  defp status_label(:new), do: "NEW"
  defp status_label(:in_progress), do: "IN PROGRESS"
  defp status_label(:archived), do: "ARCHIVED"

  defp type_label(:bug), do: "BUG"
  defp type_label(:feature_request), do: "FEATURE"

  defp priority_indicator(:critical), do: {"!", "text-error"}
  defp priority_indicator(:high), do: {"!", "text-warning"}
  defp priority_indicator(:medium), do: {"-", "text-muted"}
  defp priority_indicator(:low), do: {".", "text-muted/70"}

  @impl true
  def render(assigns) do
    ~H"""
    <FFWeb.Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      active_nav={:issues}
    >
      <div class="h-full flex flex-col">
        <%!-- Page header with terminal aesthetic --%>
        <div class="px-4 sm:px-6 py-4 sm:py-5 border-b border-base-300/50 bg-base-100">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-3 sm:gap-4">
              <div class="size-9 sm:size-10 rounded-sm bg-primary/10 border border-primary/20 flex items-center justify-center">
                <.icon name="hero-bug-ant" class="size-4 sm:size-5 text-primary" />
              </div>
              <div>
                <h1 class="text-base sm:text-lg font-semibold text-base-content">Issues</h1>
                <div class="font-mono text-[11px] sm:text-xs text-muted mt-0.5">
                  {@total} issues
                </div>
              </div>
            </div>

            <.link
              :if={@can_manage}
              navigate={~p"/dashboard/#{@current_scope.account.slug}/issues/new"}
              class="btn-primary py-2 px-3 font-mono text-xs"
            >
              <.icon name="hero-plus" class="size-3.5 mr-1" /> New Issue
            </.link>
          </div>

          <%!-- Terminal-style filters row --%>
          <div class="flex flex-wrap items-center gap-2 sm:gap-3">
            <form phx-change="filter_status">
              <select
                name="status"
                class="select-minimal font-mono text-xs sm:text-sm"
                aria-label="Filter by status"
              >
                <option value="" selected={@status_filter == ""}>--status=*</option>
                <option value="new" selected={@status_filter == "new"}>--status=new</option>
                <option value="in_progress" selected={@status_filter == "in_progress"}>
                  --status=in_progress
                </option>
                <option value="archived" selected={@status_filter == "archived"}>
                  --status=archived
                </option>
              </select>
            </form>

            <form phx-change="filter_type">
              <select
                name="type"
                class="select-minimal font-mono text-xs sm:text-sm"
                aria-label="Filter by type"
              >
                <option value="" selected={@type_filter == ""}>--type=*</option>
                <option value="bug" selected={@type_filter == "bug"}>--type=bug</option>
                <option value="feature_request" selected={@type_filter == "feature_request"}>
                  --type=feature
                </option>
              </select>
            </form>
          </div>
        </div>

        <%!-- List content --%>
        <div class="flex-1 overflow-auto px-2 sm:px-4">
          <%!-- Table header (hidden on mobile) --%>
          <div :if={@total > 0} class="group-header sticky top-0 z-10 !gap-0 hidden sm:flex">
            <div class="w-6 shrink-0"></div>
            <div class="flex-1 min-w-0 mr-4">TITLE</div>
            <div class="hidden md:block w-20 shrink-0 mr-4">PROJECT</div>
            <div class="w-16 shrink-0 mr-4">TYPE</div>
            <div class="w-24 shrink-0 mr-4">STATUS</div>
            <div class="hidden lg:block w-36 shrink-0">CREATED</div>
          </div>

          <%!-- Issues list --%>
          <div id="issues-list" class="animate-stagger space-y-2 sm:space-y-0 pt-3 sm:pt-0">
            <%= for issue <- @issues do %>
              <%!-- Mobile card layout --%>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/issues/#{issue.id}"}
                class="sm:hidden issue-card p-4 rounded-lg border border-base-300/50 bg-base-100 block hover:border-primary/30 transition-colors"
                id={"issue-mobile-#{issue.id}"}
              >
                <div class="flex items-start justify-between gap-3 mb-3">
                  <div class="flex-1 min-w-0">
                    <span class={[
                      "font-medium block",
                      issue.status == :archived && "line-through opacity-40"
                    ]}>
                      {issue.title}
                    </span>
                    <span class="text-xs text-muted font-mono mt-1 block">
                      {issue.project.name}
                    </span>
                  </div>
                  <div class="flex items-center gap-1">
                    <% {symbol, color} = priority_indicator(issue.priority) %>
                    <span class={["font-mono text-sm font-bold", color]}>{symbol}</span>
                  </div>
                </div>
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <span class={[
                      "status-badge",
                      issue.type == :bug && "status-badge-error",
                      issue.type == :feature_request && "status-badge-active"
                    ]}>
                      {type_label(issue.type)}
                    </span>
                    <span class={["status-badge", status_class(issue.status)]}>
                      {status_label(issue.status)}
                    </span>
                  </div>
                  <span class="text-xs text-muted font-mono">
                    {format_datetime(issue.inserted_at)}
                  </span>
                </div>
              </.link>

              <%!-- Desktop row layout --%>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/issues/#{issue.id}"}
                class="data-row group hidden sm:flex cursor-pointer"
                id={"issue-#{issue.id}"}
              >
                <%!-- Priority indicator --%>
                <div class="w-6 shrink-0 flex justify-center">
                  <% {symbol, color} = priority_indicator(issue.priority) %>
                  <span class={["font-mono text-sm font-bold", color]}>{symbol}</span>
                </div>

                <%!-- Issue title --%>
                <div class="flex-1 min-w-0 mr-4">
                  <span class={[
                    "font-medium truncate block",
                    issue.status == :archived && "line-through opacity-40"
                  ]}>
                    {issue.title}
                  </span>
                </div>

                <%!-- Project --%>
                <div class="hidden md:block w-20 shrink-0 mr-4">
                  <span class="text-sm text-muted truncate block font-mono">
                    {issue.project.name}
                  </span>
                </div>

                <%!-- Type badge --%>
                <div class="w-16 shrink-0 mr-4">
                  <span class={[
                    "status-badge",
                    issue.type == :bug && "status-badge-error",
                    issue.type == :feature_request && "status-badge-active"
                  ]}>
                    {type_label(issue.type)}
                  </span>
                </div>

                <%!-- Status badge --%>
                <div class="w-24 shrink-0 mr-4">
                  <span class={["status-badge", status_class(issue.status)]}>
                    {status_label(issue.status)}
                  </span>
                </div>

                <%!-- Date --%>
                <div class="hidden lg:block w-36 shrink-0">
                  <span class="text-sm text-muted font-mono">
                    {format_datetime(issue.inserted_at)}
                  </span>
                </div>
              </.link>
            <% end %>
          </div>

          <%!-- Empty state with terminal aesthetic --%>
          <div :if={@total == 0} class="flex flex-col items-center justify-center py-20 text-muted">
            <div class="size-16 rounded-sm bg-base-200 border border-base-300 flex items-center justify-center mb-6">
              <.icon name="hero-bug-ant" class="size-8 opacity-30" />
            </div>
            <div class="font-mono text-sm mb-2">$ fruitfly issues list</div>
            <div class="font-mono text-xs text-muted">No issues found.</div>
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
              patch={
                pagination_path(@current_scope.account.slug, @status_filter, @type_filter, @page - 1)
              }
              class="btn-subtle py-1.5 px-3 font-mono text-xs"
            >
              <.icon name="hero-chevron-left" class="size-3.5" />
            </.link>
            <span class="font-mono text-xs text-muted px-2">
              {@page}/{@total_pages}
            </span>
            <.link
              :if={@page < @total_pages}
              patch={
                pagination_path(@current_scope.account.slug, @status_filter, @type_filter, @page + 1)
              }
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
