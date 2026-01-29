defmodule FFWeb.Dashboard.ProjectLive.Show do
  @moduledoc """
  Dashboard view for showing a single project with edit and delete capabilities.

  Verifies the project belongs to the current account before displaying.
  Shows project details and recent issues.
  """
  use FFWeb, :live_view

  alias FF.Tracking
  alias FF.Tracking.Issue
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

        socket
        |> assign(:page_title, project.name)
        |> assign(:project, project)
        |> assign(:issue_count, issue_count)
        |> assign(:recent_issues, recent_issues)
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
    account = socket.assigns.current_scope.account

    if Scope.can_manage_account?(socket.assigns.current_scope) do
      # Re-fetch project to prevent TOCTOU race condition
      case Tracking.get_project(account, socket.assigns.project.id) do
        nil ->
          {:noreply,
           socket
           |> put_flash(:error, "Project not found.")
           |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects")}

        project ->
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
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to delete projects.")}
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
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center gap-3 sm:gap-4">
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/projects"}
                class="size-9 sm:size-10 rounded-sm bg-base-200 border border-base-300 flex items-center justify-center hover:bg-base-300 transition-colors"
                aria-label="Back to projects"
              >
                <.icon name="hero-arrow-left" class="size-4 sm:size-5 text-muted" />
              </.link>
              <div>
                <h1 class="text-base sm:text-lg font-semibold text-base-content">{@project.name}</h1>
                <div class="font-mono text-[11px] sm:text-xs text-muted mt-0.5 flex items-center gap-2">
                  <span class="status-badge status-badge-active font-mono">
                    {@project.prefix}
                  </span>
                  <span>{@issue_count} issue{if @issue_count != 1, do: "s", else: ""}</span>
                </div>
              </div>
            </div>

            <div :if={@can_manage} class="flex items-center gap-2">
              <.link
                patch={~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/edit"}
                class="btn-subtle py-1.5 px-3 font-mono text-xs"
              >
                <.icon name="hero-pencil-square" class="size-3.5 mr-1" /> Edit
              </.link>
              <button
                phx-click="delete"
                data-confirm="Are you sure you want to delete this project? All issues in this project will also be deleted. This cannot be undone."
                class="btn-subtle py-1.5 px-3 font-mono text-xs text-error hover:bg-error/10"
              >
                <.icon name="hero-trash" class="size-3.5 mr-1" /> Delete
              </button>
            </div>
          </div>
        </div>

        <%!-- Project details --%>
        <div class="flex-1 overflow-auto px-4 sm:px-6 py-6">
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <%!-- Main content --%>
            <div class="lg:col-span-2 space-y-6">
              <%!-- Description --%>
              <div class="terminal-card">
                <div class="group-header !border-b-0 !py-2 !px-4">DESCRIPTION</div>
                <div class="p-4 pt-2">
                  <div
                    :if={@project.description}
                    class="prose prose-sm max-w-none text-base-content/80"
                  >
                    <p class="whitespace-pre-wrap">{@project.description}</p>
                  </div>
                  <div :if={!@project.description} class="text-muted font-mono text-sm italic">
                    No description provided.
                  </div>
                </div>
              </div>

              <%!-- Recent issues --%>
              <div class="terminal-card">
                <div class="group-header !border-b-0 !py-2 !px-4 flex items-center justify-between">
                  <span>RECENT ISSUES</span>
                  <.link
                    :if={@issue_count > 0}
                    navigate={
                      ~p"/dashboard/#{@current_scope.account.slug}/issues?project_id=#{@project.id}"
                    }
                    class="text-primary text-xs hover:underline"
                  >
                    View all
                  </.link>
                </div>
                <div class="p-4 pt-2">
                  <div :if={@recent_issues == []} class="text-muted font-mono text-sm italic">
                    No issues yet.
                  </div>
                  <div :if={@recent_issues != []} class="space-y-2">
                    <%= for issue <- @recent_issues do %>
                      <.link
                        navigate={~p"/dashboard/#{@current_scope.account.slug}/issues/#{issue.id}"}
                        class="flex items-center gap-3 p-2 rounded-sm hover:bg-base-200 transition-colors"
                      >
                        <span class={["status-badge text-xs", type_class(issue.type)]}>
                          {type_label(issue.type)}
                        </span>
                        <span class="font-mono text-sm flex-1 truncate">
                          {Issue.issue_key(issue) || issue.id |> String.slice(0, 8)}: {issue.title}
                        </span>
                        <span class={["status-badge text-xs", status_class(issue.status)]}>
                          {status_label(issue.status)}
                        </span>
                      </.link>
                    <% end %>
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
                    <span class="text-muted text-xs font-mono">PREFIX</span>
                    <span class="status-badge status-badge-active font-mono">{@project.prefix}</span>
                  </div>
                  <div class="flex justify-between items-center">
                    <span class="text-muted text-xs font-mono">ISSUES</span>
                    <span class="font-mono text-sm">{@issue_count}</span>
                  </div>
                  <div class="flex justify-between items-center">
                    <span class="text-muted text-xs font-mono">NEXT ISSUE</span>
                    <span class="font-mono text-sm text-muted">
                      {@project.prefix}-{@project.issue_counter}
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
                    <span class="font-mono text-sm">{format_datetime(@project.inserted_at)}</span>
                  </div>
                  <div class="flex justify-between items-center">
                    <span class="text-muted text-xs font-mono">UPDATED</span>
                    <span class="font-mono text-sm">{format_datetime(@project.updated_at)}</span>
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
            <span>Read-only access. Contact an admin to modify this project.</span>
          </div>
        </div>
      </div>

      <%!-- Edit Modal --%>
      <.modal
        :if={@live_action == :edit}
        id="project-modal"
        show
        on_cancel={JS.patch(~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}")}
      >
        <div class="p-6">
          <h3 class="text-lg font-semibold mb-4">Edit Project</h3>
          <.form for={@form} id="project-form" phx-change="validate" phx-submit="save">
            <div class="space-y-5">
              <%!-- Name field --%>
              <div>
                <label for={@form[:name].id} class="label font-mono text-xs uppercase">
                  Name <span class="text-error">*</span>
                </label>
                <.input
                  field={@form[:name]}
                  type="text"
                  placeholder="My Project"
                  class="input-field font-mono"
                />
              </div>

              <%!-- Prefix field --%>
              <div>
                <label for={@form[:prefix].id} class="label font-mono text-xs uppercase">
                  Prefix <span class="text-error">*</span>
                </label>
                <.input
                  field={@form[:prefix]}
                  type="text"
                  placeholder="PRJ"
                  maxlength="10"
                  class="input-field font-mono uppercase"
                />
                <p class="mt-1 text-xs text-muted font-mono">
                  Changing the prefix will affect how new issues are displayed.
                </p>
              </div>

              <%!-- Description field --%>
              <div>
                <label for={@form[:description].id} class="label font-mono text-xs uppercase">
                  Description
                </label>
                <.input
                  field={@form[:description]}
                  type="textarea"
                  rows="3"
                  placeholder="Optional project description..."
                  class="input-field font-mono"
                />
              </div>

              <%!-- Actions --%>
              <div class="flex items-center justify-end gap-3 pt-4 border-t border-base-300/50">
                <.link
                  patch={~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}"}
                  class="btn-subtle py-2 px-4 font-mono text-sm"
                >
                  Cancel
                </.link>
                <button type="submit" class="btn-primary py-2 px-4 font-mono text-sm">
                  Save Changes
                </button>
              </div>
            </div>
          </.form>
        </div>
      </.modal>
    </FFWeb.Layouts.dashboard>
    """
  end
end
