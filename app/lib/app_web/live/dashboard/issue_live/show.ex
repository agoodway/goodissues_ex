defmodule FFWeb.Dashboard.IssueLive.Show do
  @moduledoc """
  Dashboard view for showing a single issue with edit and delete capabilities.

  Verifies the issue belongs to the current account before displaying.
  Supports inline editing via modal.
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
        |> push_patch(to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/issues/#{id}")

      true ->
        socket
        |> assign(:page_title, "Edit: #{socket.assigns.issue.title}")
    end
  end

  defp load_issue(socket, id) do
    account = socket.assigns.current_scope.account

    case Tracking.get_issue(account, id, preload: [:project, :submitter]) do
      nil ->
        socket
        |> put_flash(:error, "Issue not found.")
        |> push_navigate(to: ~p"/dashboard/#{account.slug}/issues")

      issue ->
        socket
        |> assign(:page_title, issue.title)
        |> assign(:issue, issue)
        |> assign(:projects, Tracking.list_projects(account))
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    account = socket.assigns.current_scope.account

    if Scope.can_manage_account?(socket.assigns.current_scope) do
      # Re-fetch issue to prevent TOCTOU race condition
      case Tracking.get_issue(account, socket.assigns.issue.id) do
        nil ->
          {:noreply,
           socket
           |> put_flash(:error, "Issue not found.")
           |> push_navigate(to: ~p"/dashboard/#{account.slug}/issues")}

        issue ->
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
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to delete issues.")}
    end
  end

  @impl true
  def handle_info({FFWeb.Dashboard.IssueLive.FormComponent, {:saved, issue}}, socket) do
    # Refresh issue data after edit
    case Tracking.get_issue(socket.assigns.current_scope.account, issue.id,
           preload: [:project, :submitter]
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

  defp status_class(:new), do: "status-badge-info"
  defp status_class(:in_progress), do: "status-badge-pending"
  defp status_class(:archived), do: "status-badge-muted"

  defp status_label(:new), do: "NEW"
  defp status_label(:in_progress), do: "IN PROGRESS"
  defp status_label(:archived), do: "ARCHIVED"

  defp type_class(:bug), do: "status-badge-error"
  defp type_class(:feature_request), do: "status-badge-active"

  defp type_label(:bug), do: "BUG"
  defp type_label(:feature_request), do: "FEATURE"

  defp priority_class(:critical), do: "text-error font-bold"
  defp priority_class(:high), do: "text-warning font-bold"
  defp priority_class(:medium), do: "text-muted"
  defp priority_class(:low), do: "text-muted/70"

  defp priority_label(:critical), do: "CRITICAL"
  defp priority_label(:high), do: "HIGH"
  defp priority_label(:medium), do: "MEDIUM"
  defp priority_label(:low), do: "LOW"

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
        <%!-- Page header --%>
        <div class="px-4 sm:px-6 py-4 sm:py-5 border-b border-base-300/50 bg-base-100">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-3 sm:gap-4">
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/issues"}
                class="size-9 sm:size-10 rounded-sm bg-base-200 border border-base-300 flex items-center justify-center hover:bg-base-300 transition-colors"
              >
                <.icon name="hero-arrow-left" class="size-4 sm:size-5 text-muted" />
              </.link>
              <div>
                <h1 class="text-base sm:text-lg font-semibold text-base-content">{@issue.title}</h1>
                <div class="font-mono text-[11px] sm:text-xs text-muted mt-0.5 flex items-center gap-2">
                  <span class={["status-badge", type_class(@issue.type)]}>
                    {type_label(@issue.type)}
                  </span>
                  <span class={["status-badge", status_class(@issue.status)]}>
                    {status_label(@issue.status)}
                  </span>
                </div>
              </div>
            </div>

            <div :if={@can_manage} class="flex items-center gap-2">
              <.link
                patch={~p"/dashboard/#{@current_scope.account.slug}/issues/#{@issue.id}/edit"}
                class="btn-subtle py-1.5 px-3 font-mono text-xs"
              >
                <.icon name="hero-pencil-square" class="size-3.5 mr-1" /> Edit
              </.link>
              <button
                phx-click="delete"
                data-confirm="Are you sure you want to delete this issue? This cannot be undone."
                class="btn-subtle py-1.5 px-3 font-mono text-xs text-error hover:bg-error/10"
              >
                <.icon name="hero-trash" class="size-3.5 mr-1" /> Delete
              </button>
            </div>
          </div>
        </div>

        <%!-- Issue details --%>
        <div class="flex-1 overflow-auto px-4 sm:px-6 py-6">
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <%!-- Main content --%>
            <div class="lg:col-span-2 space-y-6">
              <%!-- Description --%>
              <div class="terminal-card">
                <div class="group-header !border-b-0 !py-2 !px-4">DESCRIPTION</div>
                <div class="p-4 pt-2">
                  <div :if={@issue.description} class="prose prose-sm max-w-none text-base-content/80">
                    <p class="whitespace-pre-wrap">{@issue.description}</p>
                  </div>
                  <div :if={!@issue.description} class="text-muted font-mono text-sm italic">
                    No description provided.
                  </div>
                </div>
              </div>
            </div>

            <%!-- Sidebar --%>
            <div class="space-y-4">
              <%!-- Details card --%>
              <div class="terminal-card">
                <div class="group-header !border-b-0 !py-2 !px-4">DETAILS</div>
                <div class="p-4 pt-2 space-y-3">
                  <div class="flex justify-between items-center">
                    <span class="text-muted text-xs font-mono">PROJECT</span>
                    <span class="font-mono text-sm">{@issue.project.name}</span>
                  </div>
                  <div class="flex justify-between items-center">
                    <span class="text-muted text-xs font-mono">TYPE</span>
                    <span class={["status-badge", type_class(@issue.type)]}>
                      {type_label(@issue.type)}
                    </span>
                  </div>
                  <div class="flex justify-between items-center">
                    <span class="text-muted text-xs font-mono">STATUS</span>
                    <span class={["status-badge", status_class(@issue.status)]}>
                      {status_label(@issue.status)}
                    </span>
                  </div>
                  <div class="flex justify-between items-center">
                    <span class="text-muted text-xs font-mono">PRIORITY</span>
                    <span class={["font-mono text-xs uppercase", priority_class(@issue.priority)]}>
                      {priority_label(@issue.priority)}
                    </span>
                  </div>
                </div>
              </div>

              <%!-- People card --%>
              <div class="terminal-card">
                <div class="group-header !border-b-0 !py-2 !px-4">PEOPLE</div>
                <div class="p-4 pt-2 space-y-3">
                  <div class="flex justify-between items-center">
                    <span class="text-muted text-xs font-mono">SUBMITTER</span>
                    <span
                      class="font-mono text-sm truncate max-w-[150px]"
                      title={@issue.submitter && @issue.submitter.email}
                    >
                      {(@issue.submitter && @issue.submitter.email) || @issue.submitter_email || "-"}
                    </span>
                  </div>
                </div>
              </div>

              <%!-- Dates card --%>
              <div class="terminal-card">
                <div class="group-header !border-b-0 !py-2 !px-4">TIMESTAMPS</div>
                <div class="p-4 pt-2 space-y-3">
                  <div class="flex justify-between items-center">
                    <span class="text-muted text-xs font-mono">CREATED</span>
                    <span class="font-mono text-sm">{format_datetime(@issue.inserted_at)}</span>
                  </div>
                  <div class="flex justify-between items-center">
                    <span class="text-muted text-xs font-mono">UPDATED</span>
                    <span class="font-mono text-sm">{format_datetime(@issue.updated_at)}</span>
                  </div>
                  <div :if={@issue.archived_at} class="flex justify-between items-center">
                    <span class="text-muted text-xs font-mono">ARCHIVED</span>
                    <span class="font-mono text-sm">{format_datetime(@issue.archived_at)}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Read-only notice --%>
        <div :if={!@can_manage} class="px-6 py-3 border-t border-base-300/50 bg-base-100">
          <div class="flex items-center gap-2 text-muted font-mono text-xs">
            <.icon name="hero-information-circle" class="size-4" />
            <span>Read-only access. Contact an admin to modify this issue.</span>
          </div>
        </div>
      </div>

      <%!-- Edit Modal --%>
      <.modal
        :if={@live_action == :edit}
        id="issue-modal"
        show
        on_cancel={JS.patch(~p"/dashboard/#{@current_scope.account.slug}/issues/#{@issue.id}")}
      >
        <.live_component
          module={FFWeb.Dashboard.IssueLive.FormComponent}
          id={@issue.id}
          title="Edit Issue"
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
