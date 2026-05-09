defmodule FFWeb.Dashboard.ProjectLive.Show do
  @moduledoc """
  Dashboard view for showing a single project with edit and delete capabilities.

  Verifies the project belongs to the current account before displaying.
  Shows project details and recent issues.
  """
  use FFWeb, :live_view

  alias FF.Accounts.Scope
  alias FF.Monitoring
  alias FF.Tracking
  alias FF.Tracking.Issue

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :can_manage, Scope.can_manage_account?(socket.assigns.current_scope))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    load_project(socket, id)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket = load_project(socket, id)

    cond do
      is_nil(socket.assigns[:project]) ->
        socket

      not socket.assigns.can_manage ->
        socket
        |> put_flash(:error, "You don't have permission to edit projects.")
        |> push_patch(
          to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/projects/#{id}"
        )

      true ->
        changeset = Tracking.change_project(socket.assigns.project)

        socket
        |> assign(:page_title, "Edit: #{socket.assigns.project.name}")
        |> assign(:form, to_form(changeset))
    end
  end

  defp load_project(socket, id) do
    account = socket.assigns.current_scope.account

    case Tracking.get_project(account, id) do
      nil ->
        socket
        |> put_flash(:error, "Project not found.")
        |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects")

      project ->
        issue_count = Tracking.count_issues(project)
        recent_issues = get_recent_issues(account, project.id)
        check_status = Monitoring.count_checks_by_status(account, project.id)

        socket
        |> assign(:page_title, project.name)
        |> assign(:project, project)
        |> assign(:issue_count, issue_count)
        |> assign(:recent_issues, recent_issues)
        |> assign(:check_status, check_status)
    end
  end

  defp get_recent_issues(account, project_id) do
    %{issues: issues} =
      Tracking.list_issues_paginated(account, %{project_id: project_id, per_page: 5})

    issues
  end

  @impl true
  def handle_event("validate", %{"project" => project_params}, socket) do
    changeset =
      socket.assigns.project
      |> Tracking.change_project(project_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"project" => project_params}, socket) do
    account = socket.assigns.current_scope.account

    case Tracking.update_project(socket.assigns.project, project_params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project updated successfully.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects/#{project.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      do_delete_project(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to delete projects.")}
    end
  end

  defp do_delete_project(socket) do
    account = socket.assigns.current_scope.account

    case Tracking.get_project(account, socket.assigns.project.id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Project not found.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects")}

      project ->
        delete_and_redirect(socket, project, account)
    end
  end

  defp delete_and_redirect(socket, project, account) do
    case Tracking.delete_project(project) do
      {:ok, _project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project deleted successfully.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete project.")}
    end
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end

  defp status_label(:new), do: "NEW"
  defp status_label(:in_progress), do: "IN PROGRESS"
  defp status_label(:archived), do: "ARCHIVED"

  defp issue_type_class(:bug), do: "project-issue-type-bug"
  defp issue_type_class(:incident), do: "project-issue-type-incident"
  defp issue_type_class(:feature_request), do: "project-issue-type-feature"

  defp issue_type_icon(:bug), do: "hero-bug-ant"
  defp issue_type_icon(:incident), do: "hero-exclamation-triangle"
  defp issue_type_icon(:feature_request), do: "hero-sparkles"

  defp issue_status_class(:new), do: "project-issue-status-new"
  defp issue_status_class(:in_progress), do: "project-issue-status-progress"
  defp issue_status_class(:archived), do: "project-issue-status-archived"

  defp check_status_summary(%{down: down} = status) when down > 0 do
    parts = ["#{down} down"]
    parts = if status.up > 0, do: parts ++ ["#{status.up} up"], else: parts
    Enum.join(parts, ", ")
  end

  defp check_status_summary(%{up: up, paused: 0, unknown: 0}) when up > 0, do: "All clear"

  defp check_status_summary(status) do
    []
    |> then(fn parts -> if status.up > 0, do: parts ++ ["#{status.up} up"], else: parts end)
    |> then(fn parts ->
      if status.paused > 0, do: parts ++ ["#{status.paused} paused"], else: parts
    end)
    |> then(fn parts ->
      if status.unknown > 0, do: parts ++ ["#{status.unknown} unknown"], else: parts
    end)
    |> Enum.join(", ")
  end

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
      <div class="h-full flex flex-col project-detail-page">
        <%!-- Hero header with dramatic gradient --%>
        <div class="project-hero relative overflow-hidden">
          <%!-- Background effects --%>
          <div class="absolute inset-0 project-hero-gradient"></div>
          <div class="absolute inset-0 project-hero-grid"></div>
          <div class="absolute top-0 right-0 w-96 h-96 project-hero-glow"></div>

          <div class="relative z-10 px-4 sm:px-6 py-5 sm:py-6">
            <%!-- Navigation breadcrumb --%>
            <div class="flex items-center gap-2 mb-4">
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/projects"}
                class="project-back-link group"
              >
                <.icon
                  name="hero-arrow-left"
                  class="size-4 group-hover:-translate-x-0.5 transition-transform"
                />
                <span>Projects</span>
              </.link>
              <span class="text-base-content/20 font-mono">/</span>
              <span class="font-mono text-xs text-base-content/50">{@project.prefix}</span>
            </div>

            <%!-- Project identity --%>
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-3 mb-2">
                  <div class="project-prefix-badge">
                    <span class="project-prefix-icon">
                      <.icon name="hero-folder" class="size-4" />
                    </span>
                    <span class="project-prefix-text">{@project.prefix}</span>
                  </div>
                </div>

                <h1 class="project-title">{@project.name}</h1>

                <div class="flex flex-wrap items-center gap-3 mt-3">
                  <div class="project-stat-indicator">
                    <.icon name="hero-ticket" class="size-3.5" />
                    <span>{@issue_count} issue{if @issue_count != 1, do: "s", else: ""}</span>
                  </div>
                  <div class="project-meta-divider"></div>
                  <div class="project-stat-indicator">
                    <.icon name="hero-hashtag" class="size-3.5" />
                    <span>Next: {@project.prefix}-{@project.issue_counter}</span>
                  </div>
                  <div class="project-meta-divider"></div>
                  <div class="project-meta-item">
                    <.icon name="hero-clock" class="size-3.5" />
                    <span>Updated {format_relative_time(@project.updated_at)}</span>
                  </div>
                </div>
              </div>

              <%!-- Action buttons --%>
              <div :if={@can_manage} class="flex items-center gap-2 shrink-0">
                <.link
                  patch={~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/edit"}
                  class="project-action-btn project-action-edit"
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                  <span class="hidden sm:inline">Edit</span>
                </.link>
                <button
                  phx-click="delete"
                  data-confirm="Are you sure you want to delete this project? All issues in this project will also be deleted. This cannot be undone."
                  class="project-action-btn project-action-delete"
                >
                  <.icon name="hero-trash" class="size-4" />
                  <span class="hidden sm:inline">Delete</span>
                </button>
              </div>
            </div>
          </div>
        </div>

        <%!-- Content area --%>
        <div class="flex-1 overflow-auto">
          <div class="px-4 sm:px-6 py-6">
            <div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
              <%!-- Main content --%>
              <div class="lg:col-span-8 space-y-6">
                <%!-- Description card --%>
                <div class="project-card">
                  <div class="project-card-header">
                    <div class="project-card-header-icon">
                      <.icon name="hero-document-text" class="size-4" />
                    </div>
                    <span>Description</span>
                  </div>
                  <div class="project-card-body">
                    <div :if={@project.description} class="project-description">
                      <p>{@project.description}</p>
                    </div>
                    <div :if={!@project.description} class="project-empty-state">
                      <.icon name="hero-document" class="size-8 opacity-30" />
                      <span>No description provided</span>
                    </div>
                  </div>
                </div>

                <%!-- Recent issues card --%>
                <div class="project-card project-card-issues">
                  <div class="project-card-header">
                    <div class="project-card-header-icon">
                      <.icon name="hero-ticket" class="size-4" />
                    </div>
                    <span>Recent Issues</span>
                    <div class="project-card-header-actions">
                      <.link
                        :if={@issue_count > 0}
                        navigate={
                          ~p"/dashboard/#{@current_scope.account.slug}/issues?project_id=#{@project.id}"
                        }
                        class="project-view-all-link"
                      >
                        View all <.icon name="hero-arrow-right" class="size-3.5" />
                      </.link>
                    </div>
                  </div>
                  <div class="project-card-body !p-0">
                    <div :if={@recent_issues == []} class="project-empty-state py-8">
                      <.icon name="hero-inbox" class="size-10 opacity-20" />
                      <span class="mt-2">No issues yet</span>
                      <.link
                        :if={@can_manage}
                        navigate={~p"/dashboard/#{@current_scope.account.slug}/issues/new"}
                        class="project-create-issue-link mt-3"
                      >
                        <.icon name="hero-plus" class="size-4" /> Create first issue
                      </.link>
                    </div>
                    <div :if={@recent_issues != []} class="project-issues-list">
                      <%= for issue <- @recent_issues do %>
                        <.link
                          navigate={~p"/dashboard/#{@current_scope.account.slug}/issues/#{issue.id}"}
                          class="project-issue-row"
                        >
                          <div class="project-issue-row-left">
                            <div class={["project-issue-type", issue_type_class(issue.type)]}>
                              <.icon name={issue_type_icon(issue.type)} class="size-3" />
                            </div>
                            <span class="project-issue-key">{Issue.issue_key(issue)}</span>
                            <span class="project-issue-title">{issue.title}</span>
                          </div>
                          <div class="project-issue-row-right">
                            <span class={["project-issue-status", issue_status_class(issue.status)]}>
                              {status_label(issue.status)}
                            </span>
                            <span class="project-issue-time">
                              {format_relative_time(issue.inserted_at)}
                            </span>
                          </div>
                        </.link>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Sidebar --%>
              <div class="lg:col-span-4 space-y-5">
                <%!-- Quick stats card --%>
                <div class="project-sidebar-card project-stats-card">
                  <div class="project-stats-grid">
                    <div class="project-stat-box">
                      <span class="project-stat-value">{@issue_count}</span>
                      <span class="project-stat-label">Issues</span>
                    </div>
                    <div class="project-stat-box">
                      <span class="project-stat-value project-stat-value-next">
                        {@project.issue_counter}
                      </span>
                      <span class="project-stat-label">Next #</span>
                    </div>
                  </div>
                </div>

                <%!-- Monitoring card --%>
                <div class="project-sidebar-card">
                  <div class="project-sidebar-header">
                    <.icon name="hero-signal" class="size-4" />
                    <span>Monitoring</span>
                  </div>
                  <div class="project-sidebar-body">
                    <% total_checks =
                      @check_status.up + @check_status.down + @check_status.unknown +
                        @check_status.paused %>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Checks</span>
                      <span class="project-detail-value">{total_checks}</span>
                    </div>
                    <div :if={total_checks > 0} class="project-detail-row">
                      <span class="project-detail-label">Status</span>
                      <span class="project-detail-value font-mono text-xs">
                        {check_status_summary(@check_status)}
                      </span>
                    </div>
                    <div class="mt-3 flex flex-col gap-2">
                      <.link
                        navigate={
                          ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks"
                        }
                        class="project-view-all-link"
                      >
                        View checks <.icon name="hero-arrow-right" class="size-3.5" />
                      </.link>
                      <.link
                        :if={@can_manage && total_checks == 0}
                        navigate={
                          ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks/new"
                        }
                        class="project-create-issue-link"
                      >
                        <.icon name="hero-plus" class="size-4" /> Create first check
                      </.link>
                    </div>
                  </div>
                </div>

                <%!-- Details card --%>
                <div class="project-sidebar-card">
                  <div class="project-sidebar-header">
                    <.icon name="hero-information-circle" class="size-4" />
                    <span>Details</span>
                  </div>
                  <div class="project-sidebar-body">
                    <div class="project-detail-row">
                      <span class="project-detail-label">Prefix</span>
                      <span class="project-detail-value project-detail-prefix">
                        {@project.prefix}
                      </span>
                    </div>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Issue Count</span>
                      <span class="project-detail-value">{@issue_count}</span>
                    </div>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Next Issue</span>
                      <span class="project-detail-value text-muted">
                        {@project.prefix}-{@project.issue_counter}
                      </span>
                    </div>
                  </div>
                </div>

                <%!-- Timeline card --%>
                <div class="project-sidebar-card">
                  <div class="project-sidebar-header">
                    <.icon name="hero-clock" class="size-4" />
                    <span>Timeline</span>
                  </div>
                  <div class="project-sidebar-body">
                    <div class="project-timeline">
                      <div class="project-timeline-item">
                        <div class="project-timeline-dot project-timeline-dot-created"></div>
                        <div class="project-timeline-content">
                          <span class="project-timeline-label">Created</span>
                          <span class="project-timeline-value">
                            {format_datetime(@project.inserted_at)}
                          </span>
                        </div>
                      </div>
                      <div class="project-timeline-item">
                        <div class="project-timeline-dot project-timeline-dot-updated"></div>
                        <div class="project-timeline-content">
                          <span class="project-timeline-label">Updated</span>
                          <span class="project-timeline-value">
                            {format_datetime(@project.updated_at)}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Read-only notice --%>
        <div :if={!@can_manage} class="project-readonly-notice">
          <.icon name="hero-lock-closed" class="size-4" />
          <span>Read-only access. Contact an admin to modify this project.</span>
        </div>
      </div>

      <%!-- Edit Modal --%>
      <.modal
        :if={@live_action == :edit}
        id="project-modal"
        show
        title="Edit Project"
        on_cancel={JS.patch(~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}")}
      >
        <div class="space-y-5">
          <.form
            for={@form}
            id="project-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <.input
              field={@form[:name]}
              type="text"
              label="Name"
              placeholder="My Project"
              required
            />

            <.input
              field={@form[:prefix]}
              type="text"
              label="Prefix"
              placeholder="PRJ"
              maxlength="10"
              required
            />
            <p class="-mt-2 text-xs text-muted font-mono">
              Changing the prefix will affect how new issues are displayed.
            </p>

            <.input
              field={@form[:description]}
              type="textarea"
              label="Description"
              rows="3"
              placeholder="Optional project description..."
            />

            <div class="modal-action">
              <.link
                patch={~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}"}
                class="btn"
              >
                Cancel
              </.link>
              <.button type="submit" variant="primary" phx-disable-with="Saving...">
                Save Changes
              </.button>
            </div>
          </.form>
        </div>
      </.modal>
    </FFWeb.Layouts.dashboard>
    """
  end
end
