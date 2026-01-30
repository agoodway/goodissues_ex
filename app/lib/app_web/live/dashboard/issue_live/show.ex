defmodule FFWeb.Dashboard.IssueLive.Show do
  @moduledoc """
  Dashboard view for showing a single issue with edit and delete capabilities.

  Verifies the issue belongs to the current account before displaying.
  Supports inline editing via modal.
  """
  use FFWeb, :live_view

  alias FF.Accounts.Scope
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
    load_issue(socket, id)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket = load_issue(socket, id)

    cond do
      is_nil(socket.assigns[:issue]) ->
        socket

      not socket.assigns.can_manage ->
        socket
        |> put_flash(:error, "You don't have permission to edit issues.")
        |> push_patch(
          to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/issues/#{id}"
        )

      true ->
        socket
        |> assign(:page_title, "Edit: #{socket.assigns.issue.title}")
    end
  end

  defp load_issue(socket, id) do
    account = socket.assigns.current_scope.account

    case Tracking.get_issue(account, id,
           preload: [:project, :submitter],
           preload_error_with_count: true
         ) do
      nil ->
        socket
        |> put_flash(:error, "Issue not found.")
        |> push_navigate(to: ~p"/dashboard/#{account.slug}/issues")

      issue ->
        socket
        |> assign(:page_title, issue.title)
        |> assign(:issue, issue)
        |> assign(:projects, Tracking.list_projects(account))
        |> assign(:stacktrace_expanded, false)
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      do_delete_issue(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to delete issues.")}
    end
  end

  def handle_event("toggle_stacktrace", _params, socket) do
    {:noreply, assign(socket, :stacktrace_expanded, !socket.assigns.stacktrace_expanded)}
  end

  def handle_event("toggle_muted", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      toggle_error_muted(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to modify errors.")}
    end
  end

  def handle_event("toggle_status", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      toggle_error_status(socket)
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to modify errors.")}
    end
  end

  defp toggle_error_muted(socket) do
    error = socket.assigns.issue.error

    case Tracking.update_error(error, %{muted: !error.muted}) do
      {:ok, updated_error} ->
        issue = %{socket.assigns.issue | error: %{error | muted: updated_error.muted}}
        {:noreply, assign(socket, :issue, issue)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update error.")}
    end
  end

  defp toggle_error_status(socket) do
    error = socket.assigns.issue.error
    new_status = if error.status == :resolved, do: :unresolved, else: :resolved

    case Tracking.update_error(error, %{status: new_status}) do
      {:ok, updated_error} ->
        issue = %{socket.assigns.issue | error: %{error | status: updated_error.status}}
        {:noreply, assign(socket, :issue, issue)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update error.")}
    end
  end

  defp do_delete_issue(socket) do
    account = socket.assigns.current_scope.account

    case Tracking.get_issue(account, socket.assigns.issue.id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Issue not found.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/issues")}

      issue ->
        delete_issue_and_redirect(socket, issue, account)
    end
  end

  defp delete_issue_and_redirect(socket, issue, account) do
    case Tracking.delete_issue(issue) do
      {:ok, _issue} ->
        {:noreply,
         socket
         |> put_flash(:info, "Issue deleted successfully.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/issues")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete issue.")}
    end
  end

  @impl true
  def handle_info({FFWeb.Dashboard.IssueLive.FormComponent, {:saved, issue}}, socket) do
    # Refresh issue data after edit
    case Tracking.get_issue(socket.assigns.current_scope.account, issue.id,
           preload: [:project, :submitter],
           preload_error_with_count: true
         ) do
      nil ->
        {:noreply, socket}

      issue ->
        {:noreply, assign(socket, :issue, issue)}
    end
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end

  defp status_label(:new), do: "NEW"
  defp status_label(:in_progress), do: "IN PROGRESS"
  defp status_label(:archived), do: "ARCHIVED"

  defp type_label(:bug), do: "BUG"
  defp type_label(:feature_request), do: "FEATURE"

  defp priority_label(:critical), do: "CRITICAL"
  defp priority_label(:high), do: "HIGH"
  defp priority_label(:medium), do: "MEDIUM"
  defp priority_label(:low), do: "LOW"

  defp error_status_label(:resolved), do: "RESOLVED"
  defp error_status_label(:unresolved), do: "UNRESOLVED"

  # New styling helper functions
  defp type_pill_class(:bug), do: "issue-type-pill-bug"
  defp type_pill_class(:feature_request), do: "issue-type-pill-feature"

  defp status_indicator_class(:new), do: "issue-status-new"
  defp status_indicator_class(:in_progress), do: "issue-status-progress"
  defp status_indicator_class(:archived), do: "issue-status-archived"

  defp priority_indicator_class(:critical), do: "issue-priority-critical"
  defp priority_indicator_class(:high), do: "issue-priority-high"
  defp priority_indicator_class(:medium), do: "issue-priority-medium"
  defp priority_indicator_class(:low), do: "issue-priority-low"

  defp type_detail_class(:bug), do: "issue-type-detail-bug"
  defp type_detail_class(:feature_request), do: "issue-type-detail-feature"

  defp status_detail_class(:new), do: "issue-status-detail-new"
  defp status_detail_class(:in_progress), do: "issue-status-detail-progress"
  defp status_detail_class(:archived), do: "issue-status-detail-archived"

  defp priority_detail_class(:critical), do: "issue-priority-detail-critical"
  defp priority_detail_class(:high), do: "issue-priority-detail-high"
  defp priority_detail_class(:medium), do: "issue-priority-detail-medium"
  defp priority_detail_class(:low), do: "issue-priority-detail-low"

  defp error_status_value_class(:resolved), do: "text-success"
  defp error_status_value_class(:unresolved), do: "text-error"

  defp format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  defp get_initials(nil), do: "?"
  defp get_initials(""), do: "?"

  defp get_initials(email) when is_binary(email) do
    email
    |> String.split("@")
    |> List.first()
    |> String.slice(0, 2)
    |> String.upcase()
  end

  defp format_stacktrace_line(line) do
    module = line.module || "unknown"
    function = line.function || "unknown"
    arity = line.arity
    file = line.file
    line_num = line.line

    location =
      if file && line_num do
        " (#{file}:#{line_num})"
      else
        ""
      end

    if arity do
      "#{module}.#{function}/#{arity}#{location}"
    else
      "#{module}.#{function}#{location}"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <FFWeb.Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      active_nav={:issues}
    >
      <div class="h-full flex flex-col issue-detail-page">
        <%!-- Hero header with dramatic gradient --%>
        <div class="issue-hero relative overflow-hidden">
          <%!-- Background effects --%>
          <div class="absolute inset-0 issue-hero-gradient"></div>
          <div class="absolute inset-0 issue-hero-grid"></div>
          <div class="absolute top-0 right-0 w-96 h-96 issue-hero-glow"></div>

          <div class="relative z-10 px-4 sm:px-6 py-5 sm:py-6">
            <%!-- Navigation breadcrumb --%>
            <div class="flex items-center gap-2 mb-4">
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/issues"}
                class="issue-back-link group"
              >
                <.icon
                  name="hero-arrow-left"
                  class="size-4 group-hover:-translate-x-0.5 transition-transform"
                />
                <span>Issues</span>
              </.link>
              <span class="text-base-content/20 font-mono">/</span>
              <span class="font-mono text-xs text-base-content/50">{@issue.project.prefix}</span>
            </div>

            <%!-- Issue key badge with glow --%>
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-3 mb-2">
                  <div class="issue-key-badge">
                    <span class="issue-key-icon">
                      <.icon
                        name={if @issue.type == :bug, do: "hero-bug-ant", else: "hero-sparkles"}
                        class="size-4"
                      />
                    </span>
                    <span class="issue-key-text">{Issue.issue_key(@issue)}</span>
                  </div>
                  <span class={["issue-type-pill", type_pill_class(@issue.type)]}>
                    {type_label(@issue.type)}
                  </span>
                </div>

                <h1 class="issue-title">{@issue.title}</h1>

                <div class="flex flex-wrap items-center gap-3 mt-3">
                  <div class={["issue-status-indicator", status_indicator_class(@issue.status)]}>
                    <span class="issue-status-dot"></span>
                    <span>{status_label(@issue.status)}</span>
                  </div>
                  <div class="issue-meta-divider"></div>
                  <div class={["issue-priority-indicator", priority_indicator_class(@issue.priority)]}>
                    <.icon name="hero-flag" class="size-3.5" />
                    <span>{priority_label(@issue.priority)}</span>
                  </div>
                  <div class="issue-meta-divider"></div>
                  <div class="issue-meta-item">
                    <.icon name="hero-clock" class="size-3.5" />
                    <span>{format_relative_time(@issue.inserted_at)}</span>
                  </div>
                </div>
              </div>

              <%!-- Action buttons --%>
              <div :if={@can_manage} class="flex items-center gap-2 shrink-0">
                <.link
                  patch={~p"/dashboard/#{@current_scope.account.slug}/issues/#{@issue.id}/edit"}
                  class="issue-action-btn issue-action-edit"
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                  <span class="hidden sm:inline">Edit</span>
                </.link>
                <button
                  phx-click="delete"
                  data-confirm="Are you sure you want to delete this issue? This cannot be undone."
                  class="issue-action-btn issue-action-delete"
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
                <div class="issue-card issue-card-description">
                  <div class="issue-card-header">
                    <div class="issue-card-header-icon">
                      <.icon name="hero-document-text" class="size-4" />
                    </div>
                    <span>Description</span>
                  </div>
                  <div class="issue-card-body">
                    <div :if={@issue.description} class="issue-description">
                      <p>{@issue.description}</p>
                    </div>
                    <div :if={!@issue.description} class="issue-empty-state">
                      <.icon name="hero-document" class="size-8 opacity-30" />
                      <span>No description provided</span>
                    </div>
                  </div>
                </div>

                <%!-- Error Data Section --%>
                <div :if={@issue.error} class="issue-card issue-card-error" id="error-data">
                  <div class="issue-card-header issue-card-header-error">
                    <div class="issue-card-header-icon issue-card-header-icon-error">
                      <.icon name="hero-exclamation-triangle" class="size-4" />
                    </div>
                    <span>Error Details</span>
                    <div class="issue-card-header-actions">
                      <div :if={@can_manage} class="flex items-center gap-2">
                        <button
                          phx-click="toggle_muted"
                          class={[
                            "issue-error-toggle",
                            @issue.error.muted && "issue-error-toggle-active"
                          ]}
                        >
                          <.icon
                            name={
                              if @issue.error.muted,
                                do: "hero-speaker-x-mark",
                                else: "hero-speaker-wave"
                            }
                            class="size-3.5"
                          />
                          <span>{if @issue.error.muted, do: "Muted", else: "Mute"}</span>
                        </button>
                        <button
                          phx-click="toggle_status"
                          class={[
                            "issue-error-toggle",
                            @issue.error.status == :resolved && "issue-error-toggle-resolved"
                          ]}
                        >
                          <.icon
                            name={
                              if @issue.error.status == :resolved,
                                do: "hero-check-circle",
                                else: "hero-x-circle"
                            }
                            class="size-3.5"
                          />
                          <span>
                            {if @issue.error.status == :resolved, do: "Resolved", else: "Resolve"}
                          </span>
                        </button>
                      </div>
                    </div>
                  </div>
                  <div class="issue-card-body space-y-5">
                    <%!-- Error stats row --%>
                    <div class="issue-error-stats">
                      <div class="issue-error-stat">
                        <span class="issue-error-stat-value">
                          {@issue.error.occurrence_count || 0}
                        </span>
                        <span class="issue-error-stat-label">Occurrences</span>
                      </div>
                      <div class="issue-error-stat-divider"></div>
                      <div class="issue-error-stat">
                        <span class={[
                          "issue-error-stat-value",
                          error_status_value_class(@issue.error.status)
                        ]}>
                          {error_status_label(@issue.error.status)}
                        </span>
                        <span class="issue-error-stat-label">Status</span>
                      </div>
                      <div class="issue-error-stat-divider"></div>
                      <div class="issue-error-stat">
                        <span class="issue-error-stat-value text-sm">
                          {format_datetime(@issue.error.last_occurrence_at)}
                        </span>
                        <span class="issue-error-stat-label">Last Seen</span>
                      </div>
                    </div>

                    <%!-- Error kind --%>
                    <div class="issue-error-field">
                      <span class="issue-error-field-label">Exception Type</span>
                      <code class="issue-error-kind">{@issue.error.kind}</code>
                    </div>

                    <%!-- Reason --%>
                    <div class="issue-error-field">
                      <span class="issue-error-field-label">Message</span>
                      <div class="issue-error-reason">
                        <code>{@issue.error.reason}</code>
                      </div>
                    </div>

                    <%!-- Collapsible stacktrace --%>
                    <div :if={
                      @issue.error.occurrences != [] &&
                        hd(@issue.error.occurrences).stacktrace_lines != []
                    }>
                      <button
                        phx-click="toggle_stacktrace"
                        class="issue-stacktrace-toggle"
                      >
                        <.icon
                          name={
                            if @stacktrace_expanded,
                              do: "hero-chevron-down",
                              else: "hero-chevron-right"
                          }
                          class="size-4 transition-transform"
                        />
                        <span>Stack Trace</span>
                        <span class="issue-stacktrace-count">
                          {length(hd(@issue.error.occurrences).stacktrace_lines)} frames
                        </span>
                      </button>
                      <div :if={@stacktrace_expanded} class="issue-stacktrace">
                        <div
                          :for={
                            {line, idx} <-
                              Enum.with_index(hd(@issue.error.occurrences).stacktrace_lines)
                          }
                          class="issue-stacktrace-line"
                        >
                          <span class="issue-stacktrace-num">{idx + 1}</span>
                          <span class="issue-stacktrace-code">{format_stacktrace_line(line)}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Sidebar --%>
              <div class="lg:col-span-4 space-y-5">
                <%!-- Quick info card --%>
                <div class="issue-sidebar-card">
                  <div class="issue-sidebar-header">
                    <.icon name="hero-information-circle" class="size-4" />
                    <span>Details</span>
                  </div>
                  <div class="issue-sidebar-body">
                    <div class="issue-detail-row">
                      <span class="issue-detail-label">Project</span>
                      <.link
                        navigate={
                          ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@issue.project.id}"
                        }
                        class="issue-detail-value issue-detail-link"
                      >
                        <span class="issue-project-prefix">{@issue.project.prefix}</span>
                        <span>{@issue.project.name}</span>
                      </.link>
                    </div>
                    <div class="issue-detail-row">
                      <span class="issue-detail-label">Type</span>
                      <span class={["issue-detail-badge", type_detail_class(@issue.type)]}>
                        <.icon
                          name={if @issue.type == :bug, do: "hero-bug-ant", else: "hero-sparkles"}
                          class="size-3.5"
                        />
                        {type_label(@issue.type)}
                      </span>
                    </div>
                    <div class="issue-detail-row">
                      <span class="issue-detail-label">Status</span>
                      <span class={["issue-detail-badge", status_detail_class(@issue.status)]}>
                        {status_label(@issue.status)}
                      </span>
                    </div>
                    <div class="issue-detail-row">
                      <span class="issue-detail-label">Priority</span>
                      <span class={["issue-detail-priority", priority_detail_class(@issue.priority)]}>
                        <.icon name="hero-flag" class="size-3.5" />
                        {priority_label(@issue.priority)}
                      </span>
                    </div>
                  </div>
                </div>

                <%!-- People card --%>
                <div class="issue-sidebar-card">
                  <div class="issue-sidebar-header">
                    <.icon name="hero-user-circle" class="size-4" />
                    <span>People</span>
                  </div>
                  <div class="issue-sidebar-body">
                    <div class="issue-detail-row">
                      <span class="issue-detail-label">Submitter</span>
                      <div class="issue-person">
                        <div class="issue-person-avatar">
                          {get_initials(
                            (@issue.submitter && @issue.submitter.email) || @issue.submitter_email
                          )}
                        </div>
                        <span
                          class="issue-person-email"
                          title={
                            (@issue.submitter && @issue.submitter.email) || @issue.submitter_email
                          }
                        >
                          {(@issue.submitter && @issue.submitter.email) || @issue.submitter_email ||
                            "—"}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>

                <%!-- Timeline card --%>
                <div class="issue-sidebar-card">
                  <div class="issue-sidebar-header">
                    <.icon name="hero-clock" class="size-4" />
                    <span>Timeline</span>
                  </div>
                  <div class="issue-sidebar-body">
                    <div class="issue-timeline">
                      <div class="issue-timeline-item">
                        <div class="issue-timeline-dot issue-timeline-dot-created"></div>
                        <div class="issue-timeline-content">
                          <span class="issue-timeline-label">Created</span>
                          <span class="issue-timeline-value">
                            {format_datetime(@issue.inserted_at)}
                          </span>
                        </div>
                      </div>
                      <div class="issue-timeline-item">
                        <div class="issue-timeline-dot issue-timeline-dot-updated"></div>
                        <div class="issue-timeline-content">
                          <span class="issue-timeline-label">Updated</span>
                          <span class="issue-timeline-value">
                            {format_datetime(@issue.updated_at)}
                          </span>
                        </div>
                      </div>
                      <div :if={@issue.archived_at} class="issue-timeline-item">
                        <div class="issue-timeline-dot issue-timeline-dot-archived"></div>
                        <div class="issue-timeline-content">
                          <span class="issue-timeline-label">Archived</span>
                          <span class="issue-timeline-value">
                            {format_datetime(@issue.archived_at)}
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
        <div :if={!@can_manage} class="issue-readonly-notice">
          <.icon name="hero-lock-closed" class="size-4" />
          <span>Read-only access. Contact an admin to modify this issue.</span>
        </div>
      </div>

      <%!-- Edit Modal --%>
      <.modal
        :if={@live_action == :edit}
        id="issue-modal"
        show
        title="Edit Issue"
        size={:lg}
        on_cancel={JS.patch(~p"/dashboard/#{@current_scope.account.slug}/issues/#{@issue.id}")}
      >
        <.live_component
          module={FFWeb.Dashboard.IssueLive.FormComponent}
          id={@issue.id}
          action={:edit}
          issue={@issue}
          projects={@projects}
          current_scope={@current_scope}
          patch={~p"/dashboard/#{@current_scope.account.slug}/issues/#{@issue.id}"}
        />
      </.modal>
    </FFWeb.Layouts.dashboard>
    """
  end
end
