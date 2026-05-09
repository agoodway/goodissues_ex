defmodule FFWeb.Dashboard.ProjectLive.Index do
  @moduledoc """
  Dashboard view for listing projects scoped to the current account.

  Shows all projects with their prefixes and issue counts.
  Matches the industrial terminal aesthetic from the Issues UI.
  """
  use FFWeb, :live_view

  alias FF.Accounts.Scope
  alias FF.Tracking

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :can_manage, Scope.can_manage_account?(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  defp apply_action(socket, :index) do
    account = socket.assigns.current_scope.account
    projects_with_counts = Tracking.list_projects_with_counts(account)

    socket
    |> assign(:page_title, "Projects")
    |> assign(:projects_with_counts, projects_with_counts)
    |> assign(:total, length(projects_with_counts))
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
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
        <%!-- Page header with terminal aesthetic --%>
        <div class="px-4 sm:px-6 py-4 sm:py-5 border-b border-base-300/50 bg-base-100">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-3 sm:gap-4">
              <div class="size-9 sm:size-10 rounded-sm bg-primary/10 border border-primary/20 flex items-center justify-center">
                <.icon name="hero-folder" class="size-4 sm:size-5 text-primary" />
              </div>
              <div>
                <h1 class="text-base sm:text-lg font-semibold text-base-content">Projects</h1>
                <div class="font-mono text-[11px] sm:text-xs text-muted mt-0.5">
                  {@total} projects
                </div>
              </div>
            </div>

            <.link
              :if={@can_manage}
              navigate={~p"/dashboard/#{@current_scope.account.slug}/projects/new"}
              class="btn-primary py-2 px-3 font-mono text-xs"
            >
              <.icon name="hero-plus" class="size-3.5 mr-1" /> New Project
            </.link>
          </div>
        </div>

        <%!-- List content --%>
        <div class="flex-1 overflow-auto px-2 sm:px-4">
          <%!-- Table header (hidden on mobile) --%>
          <div :if={@total > 0} class="group-header sticky top-0 z-10 !gap-0 hidden sm:flex">
            <div class="flex-1 min-w-0 mr-4">NAME</div>
            <div class="w-20 shrink-0 mr-4">PREFIX</div>
            <div class="w-20 shrink-0 mr-4">ISSUES</div>
            <div class="hidden lg:block w-36 shrink-0">CREATED</div>
          </div>

          <%!-- Projects list --%>
          <div id="projects-list" class="animate-stagger space-y-2 sm:space-y-0 pt-3 sm:pt-0">
            <%= for {project, issue_count} <- @projects_with_counts do %>
              <%!-- Mobile card layout --%>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/projects/#{project.id}"}
                class="sm:hidden project-card p-4 rounded-lg border border-base-300/50 bg-base-100 block hover:border-primary/30 transition-colors"
                id={"project-mobile-#{project.id}"}
              >
                <div class="flex items-start justify-between gap-3 mb-3">
                  <div class="flex-1 min-w-0">
                    <span class="font-medium block">{project.name}</span>
                    <span class="text-xs text-muted font-mono mt-1 block">
                      {project.description || "No description"}
                    </span>
                  </div>
                  <span class="status-badge status-badge-active font-mono">
                    {project.prefix}
                  </span>
                </div>
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-2">
                    <span class="text-xs text-muted font-mono">
                      {issue_count} issue{if issue_count != 1, do: "s", else: ""}
                    </span>
                  </div>
                  <span class="text-xs text-muted font-mono">
                    {format_datetime(project.inserted_at)}
                  </span>
                </div>
              </.link>

              <%!-- Desktop row layout --%>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/projects/#{project.id}"}
                class="data-row group hidden sm:flex cursor-pointer"
                id={"project-#{project.id}"}
              >
                <%!-- Project name --%>
                <div class="flex-1 min-w-0 mr-4">
                  <span class="font-medium truncate block">{project.name}</span>
                </div>

                <%!-- Prefix badge --%>
                <div class="w-20 shrink-0 mr-4">
                  <span class="status-badge status-badge-active font-mono">
                    {project.prefix}
                  </span>
                </div>

                <%!-- Issue count --%>
                <div class="w-20 shrink-0 mr-4">
                  <span class="text-sm text-muted font-mono">
                    {issue_count}
                  </span>
                </div>

                <%!-- Date --%>
                <div class="hidden lg:block w-36 shrink-0">
                  <span class="text-sm text-muted font-mono">
                    {format_datetime(project.inserted_at)}
                  </span>
                </div>
              </.link>
            <% end %>
          </div>

          <%!-- Empty state with terminal aesthetic --%>
          <div :if={@total == 0} class="flex flex-col items-center justify-center py-20 text-muted">
            <div class="size-16 rounded-sm bg-base-200 border border-base-300 flex items-center justify-center mb-6">
              <.icon name="hero-folder" class="size-8 opacity-30" />
            </div>
            <div class="font-mono text-sm mb-2">$ fruitfly projects list</div>
            <div class="font-mono text-xs text-muted mb-4">No projects found.</div>
            <.link
              :if={@can_manage}
              navigate={~p"/dashboard/#{@current_scope.account.slug}/projects/new"}
              class="btn-primary py-2 px-4 font-mono text-sm"
            >
              Create your first project
            </.link>
          </div>
        </div>

        <%!-- Footer --%>
        <div
          :if={@total > 0}
          class="px-6 py-3 border-t border-base-300/50 flex items-center justify-between bg-base-100"
        >
          <span class="font-mono text-xs text-muted">
            [{@total}] project{if @total != 1, do: "s", else: ""}
          </span>
        </div>
      </div>
    </FFWeb.Layouts.dashboard>
    """
  end
end
