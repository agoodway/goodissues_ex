defmodule FFWeb.Dashboard.CheckLive.New do
  @moduledoc """
  Dashboard view for creating a new uptime check.

  Uses progressive disclosure: basic fields visible by default,
  advanced settings in a collapsible section.
  """
  use FFWeb, :live_view

  alias FF.Accounts.Scope
  alias FF.Monitoring
  alias FF.Monitoring.Check
  alias FF.Tracking

  @impl true
  def mount(%{"project_id" => project_id}, _session, socket) do
    account = socket.assigns.current_scope.account

    if not Scope.can_manage_account?(socket.assigns.current_scope) do
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to create checks.")
       |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects/#{project_id}/checks")}
    else
      case Tracking.get_project(account, project_id) do
        nil ->
          {:ok,
           socket
           |> put_flash(:error, "Project not found.")
           |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects")}

        project ->
          changeset = Monitoring.change_check(%Check{})

          {:ok,
           socket
           |> assign(:page_title, "New Check")
           |> assign(:project, project)
           |> assign(:form, to_form(changeset))
           |> assign(:show_advanced, false)}
      end
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_advanced", _params, socket) do
    {:noreply, assign(socket, :show_advanced, !socket.assigns.show_advanced)}
  end

  @impl true
  def handle_event("validate", %{"check" => check_params}, socket) do
    changeset =
      %Check{}
      |> Monitoring.change_check(check_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"check" => check_params}, socket) do
    account = socket.assigns.current_scope.account
    user = socket.assigns.current_scope.user
    project = socket.assigns.project

    check_params = Map.put(check_params, "project_id", project.id)

    case Monitoring.create_check(account, user, check_params) do
      {:ok, _check} ->
        {:noreply,
         socket
         |> put_flash(:info, "Check created successfully.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects/#{project.id}/checks")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
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
        <%!-- Page header with breadcrumb --%>
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
            <.link
              navigate={~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}"}
              class="font-mono text-xs text-base-content/50 hover:text-base-content transition-colors"
            >
              {@project.prefix}
            </.link>
            <span class="text-base-content/20 font-mono">/</span>
            <.link
              navigate={~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks"}
              class="font-mono text-xs text-base-content/50 hover:text-base-content transition-colors"
            >
              Checks
            </.link>
            <span class="text-base-content/20 font-mono">/</span>
            <span class="font-mono text-xs text-base-content/50">New</span>
          </div>

          <div class="flex items-center gap-3 sm:gap-4">
            <.link
              navigate={~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks"}
              class="size-9 sm:size-10 rounded-sm bg-base-200 border border-base-300 flex items-center justify-center hover:bg-base-300 transition-colors"
            >
              <.icon name="hero-arrow-left" class="size-4 sm:size-5 text-muted" />
            </.link>
            <div>
              <h1 class="text-base sm:text-lg font-semibold text-base-content">New Check</h1>
              <div class="font-mono text-[11px] sm:text-xs text-muted mt-0.5">
                Add an uptime check for {@project.name}
              </div>
            </div>
          </div>
        </div>

        <%!-- Form content --%>
        <div class="flex-1 overflow-auto px-4 sm:px-6 py-6">
          <div class="max-w-2xl">
            <div class="terminal-card p-6">
              <.form
                for={@form}
                id="check-form"
                phx-change="validate"
                phx-submit="save"
                class="space-y-4"
              >
                <.input
                  field={@form[:name]}
                  type="text"
                  label="Name"
                  placeholder="API Health Check"
                  required
                />

                <.input
                  field={@form[:url]}
                  type="text"
                  label="URL"
                  placeholder="https://api.example.com/health"
                  required
                />

                <div class="grid grid-cols-2 gap-4">
                  <.input
                    field={@form[:method]}
                    type="select"
                    label="Method"
                    options={[{"GET", "get"}, {"HEAD", "head"}, {"POST", "post"}]}
                  />

                  <.input
                    field={@form[:interval_seconds]}
                    type="number"
                    label="Interval (seconds)"
                    min="30"
                    max="3600"
                    placeholder="300"
                  />
                </div>

                <%!-- Advanced settings toggle --%>
                <div class="border-t border-base-300/50 pt-4">
                  <button
                    type="button"
                    phx-click="toggle_advanced"
                    class="flex items-center gap-2 text-sm text-muted hover:text-base-content transition-colors font-mono"
                  >
                    <.icon
                      name={if @show_advanced, do: "hero-chevron-down", else: "hero-chevron-right"}
                      class="size-4"
                    /> Advanced Settings
                  </button>
                </div>

                <div :if={@show_advanced} class="space-y-4 pl-2 border-l-2 border-base-300/30">
                  <.input
                    field={@form[:expected_status]}
                    type="number"
                    label="Expected Status Code"
                    min="100"
                    max="599"
                    placeholder="200"
                  />

                  <.input
                    field={@form[:keyword]}
                    type="text"
                    label="Keyword"
                    placeholder="Optional keyword to check in response body"
                  />

                  <.input
                    field={@form[:keyword_absence]}
                    type="checkbox"
                    label="Alert when keyword IS present (absence check)"
                  />

                  <div class="grid grid-cols-2 gap-4">
                    <.input
                      field={@form[:failure_threshold]}
                      type="number"
                      label="Failure Threshold"
                      min="1"
                      placeholder="1"
                    />

                    <.input
                      field={@form[:reopen_window_hours]}
                      type="number"
                      label="Reopen Window (hours)"
                      min="1"
                      placeholder="24"
                    />
                  </div>

                  <.input
                    field={@form[:paused]}
                    type="checkbox"
                    label="Start paused"
                  />
                </div>

                <div class="flex items-center justify-end gap-3 pt-4 border-t border-base-300/50">
                  <.link
                    navigate={
                      ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks"
                    }
                    class="btn"
                  >
                    Cancel
                  </.link>
                  <.button type="submit" variant="primary" phx-disable-with="Creating...">
                    Create Check
                  </.button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </FFWeb.Layouts.dashboard>
    """
  end
end
