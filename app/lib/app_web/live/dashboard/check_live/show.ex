defmodule FFWeb.Dashboard.CheckLive.Show do
  @moduledoc """
  Dashboard view for showing a single uptime check with edit modal,
  delete, and paginated/filterable check results.
  """
  use FFWeb, :live_view

  alias FF.Accounts.Scope
  alias FF.Monitoring
  alias FF.Monitoring.Check
  alias FF.Tracking

  @impl true
  def mount(%{"project_id" => project_id, "id" => check_id}, _session, socket) do
    account = socket.assigns.current_scope.account

    with %{} = project <- Tracking.get_project(account, project_id),
         %Check{} = check <- Monitoring.get_check(account, project_id, check_id) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(FF.PubSub, Monitoring.checks_topic(project.id))
      end

      can_manage = Scope.can_manage_account?(socket.assigns.current_scope)

      {:ok,
       socket
       |> assign(:project, project)
       |> assign(:check, check)
       |> assign(:can_manage, can_manage)
       |> assign(:page_title, check.name)}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Check not found.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, params) do
    load_results(socket, params)
  end

  defp apply_action(socket, :edit, params) do
    socket = load_results(socket, params)

    cond do
      not socket.assigns.can_manage ->
        socket
        |> put_flash(:error, "You don't have permission to edit checks.")
        |> push_patch(
          to:
            ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/projects/#{socket.assigns.project.id}/checks/#{socket.assigns.check.id}"
        )

      true ->
        changeset = Monitoring.change_check(socket.assigns.check)

        socket
        |> assign(:page_title, "Edit: #{socket.assigns.check.name}")
        |> assign(:form, to_form(changeset))
        |> assign(:show_advanced, true)
    end
  end

  defp load_results(socket, params) do
    account = socket.assigns.current_scope.account
    project = socket.assigns.project
    check = socket.assigns.check

    page = parse_page_param(params["results_page"])
    status_filter = params["status"] || ""

    filters =
      %{page: page}
      |> maybe_add_filter(:status, status_filter)

    result = Monitoring.list_check_results(account, project.id, check.id, filters)

    socket
    |> assign(:results, result.results)
    |> assign(:results_page, result.page)
    |> assign(:results_per_page, result.per_page)
    |> assign(:results_total_pages, result.total_pages)
    |> assign(:results_total, result.total)
    |> assign(:status_filter, status_filter)
  end

  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp prepend_result(socket, result) do
    cond do
      socket.assigns.results_page != 1 ->
        # On a later page; just bump the total so pagination math stays right.
        bump_total(socket, result)

      not result_matches_filter?(result, socket.assigns.status_filter) ->
        socket

      true ->
        results =
          [result | socket.assigns.results]
          |> Enum.take(socket.assigns.results_per_page)

        socket
        |> assign(:results, results)
        |> bump_total(result)
    end
  end

  defp bump_total(socket, result) do
    if result_matches_filter?(result, socket.assigns.status_filter) do
      total = socket.assigns.results_total + 1
      total_pages = max(ceil(total / socket.assigns.results_per_page), 1)

      socket
      |> assign(:results_total, total)
      |> assign(:results_total_pages, total_pages)
    else
      socket
    end
  end

  defp result_matches_filter?(_result, ""), do: true
  defp result_matches_filter?(%{status: :up}, "up"), do: true
  defp result_matches_filter?(%{status: :down}, "down"), do: true
  defp result_matches_filter?(_result, _filter), do: false

  defp parse_page_param(nil), do: 1

  defp parse_page_param(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> 1
    end
  end

  defp parse_page_param(_), do: 1

  # Events

  @impl true
  def handle_event("toggle_advanced", _params, socket) do
    {:noreply, assign(socket, :show_advanced, !socket.assigns.show_advanced)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    account_slug = socket.assigns.current_scope.account.slug
    project_id = socket.assigns.project.id
    check_id = socket.assigns.check.id

    params = if status != "", do: %{status: status}, else: %{}

    {:noreply,
     push_patch(socket,
       to: ~p"/dashboard/#{account_slug}/projects/#{project_id}/checks/#{check_id}?#{params}"
     )}
  end

  @impl true
  def handle_event("toggle_pause", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      check = socket.assigns.check

      case Monitoring.update_check(check, %{paused: !check.paused}) do
        {:ok, updated} ->
          {:noreply, assign(socket, :check, updated)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update check.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission.")}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      case Monitoring.delete_check(socket.assigns.check) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Check deleted.")
           |> push_navigate(
             to:
               ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/projects/#{socket.assigns.project.id}/checks"
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete check.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission.")}
    end
  end

  @impl true
  def handle_event("validate", %{"check" => check_params}, socket) do
    changeset =
      socket.assigns.check
      |> Monitoring.change_check(check_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"check" => check_params}, socket) do
    case Monitoring.update_check(socket.assigns.check, check_params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:check, updated)
         |> put_flash(:info, "Check updated.")
         |> push_patch(
           to:
             ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/projects/#{socket.assigns.project.id}/checks/#{updated.id}"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  # PubSub handlers
  @impl true
  def handle_info({:check_run_completed, payload}, socket) do
    if payload.id == socket.assigns.check.id do
      {:noreply, assign(socket, :check, struct(socket.assigns.check, payload))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:check_result_created, %{check_id: check_id, result: result}}, socket) do
    if check_id == socket.assigns.check.id do
      {:noreply, prepend_result(socket, result)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:check_updated, payload}, socket) do
    if payload.id == socket.assigns.check.id do
      {:noreply, assign(socket, :check, struct(socket.assigns.check, payload))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:check_deleted, %{id: id}}, socket) do
    if id == socket.assigns.check.id do
      {:noreply,
       socket
       |> put_flash(:info, "This check was deleted.")
       |> push_navigate(
         to:
           ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/projects/#{socket.assigns.project.id}/checks"
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # Helpers

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

  defp format_datetime(nil), do: "-"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  defp results_path(account_slug, project_id, check_id, status, page) do
    params =
      %{status: status, results_page: page}
      |> Enum.reject(fn {_k, v} -> v == "" or v == 1 end)

    ~p"/dashboard/#{account_slug}/projects/#{project_id}/checks/#{check_id}?#{params}"
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
        <%!-- Hero header --%>
        <div class="project-hero relative overflow-hidden">
          <div class="absolute inset-0 project-hero-gradient"></div>
          <div class="absolute inset-0 project-hero-grid"></div>
          <div class="absolute top-0 right-0 w-96 h-96 project-hero-glow"></div>

          <div class="relative z-10 px-4 sm:px-6 py-5 sm:py-6">
            <%!-- Breadcrumb --%>
            <div class="flex items-center gap-2 mb-4">
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}"}
                class="project-back-link group"
              >
                <.icon
                  name="hero-arrow-left"
                  class="size-4 group-hover:-translate-x-0.5 transition-transform"
                />
                <span>Projects</span>
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
                navigate={
                  ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks"
                }
                class="font-mono text-xs text-base-content/50 hover:text-base-content transition-colors"
              >
                Checks
              </.link>
              <span class="text-base-content/20 font-mono">/</span>
              <span class="font-mono text-xs text-base-content/50">{@check.name}</span>
            </div>

            <%!-- Check identity --%>
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-3 mb-2">
                  <%= if @check.paused do %>
                    <span class="status-badge status-badge-muted">PAUSED</span>
                  <% else %>
                    <% {color, label} = status_indicator(@check.status) %>
                    <span class={["size-3 rounded-full", color]}></span>
                    <span class="font-mono text-xs text-muted">{label}</span>
                  <% end %>
                </div>

                <h1 class="project-title">{@check.name}</h1>

                <div class="flex flex-wrap items-center gap-3 mt-3">
                  <div class="project-stat-indicator">
                    <.icon name="hero-globe-alt" class="size-3.5" />
                    <span class="font-mono text-xs truncate max-w-xs">{@check.url}</span>
                  </div>
                  <div class="project-meta-divider"></div>
                  <div class="project-meta-item">
                    <.icon name="hero-clock" class="size-3.5" />
                    <span>Every {format_interval(@check.interval_seconds)}</span>
                  </div>
                  <div class="project-meta-divider"></div>
                  <div class="project-meta-item">
                    <.icon name="hero-arrow-path" class="size-3.5" />
                    <span>Last: {format_relative_time(@check.last_checked_at)}</span>
                  </div>
                </div>
              </div>

              <%!-- Action buttons --%>
              <div :if={@can_manage} class="flex items-center gap-2 shrink-0">
                <button
                  phx-click="toggle_pause"
                  class="project-action-btn project-action-edit"
                >
                  <%= if @check.paused do %>
                    <.icon name="hero-play" class="size-4" />
                    <span class="hidden sm:inline">Resume</span>
                  <% else %>
                    <.icon name="hero-pause" class="size-4" />
                    <span class="hidden sm:inline">Pause</span>
                  <% end %>
                </button>
                <.link
                  patch={
                    ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks/#{@check.id}/edit"
                  }
                  class="project-action-btn project-action-edit"
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                  <span class="hidden sm:inline">Edit</span>
                </.link>
                <button
                  phx-click="delete"
                  data-confirm="Are you sure you want to delete this check? This cannot be undone."
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
              <%!-- Main content: Results --%>
              <div class="lg:col-span-8 space-y-6">
                <div class="project-card">
                  <div class="project-card-header">
                    <div class="project-card-header-icon">
                      <.icon name="hero-clipboard-document-list" class="size-4" />
                    </div>
                    <span>Check Results</span>
                    <div class="project-card-header-actions">
                      <form phx-change="filter_status" class="flex items-center">
                        <select
                          name="status"
                          class="select-minimal font-mono text-xs"
                          aria-label="Filter by status"
                        >
                          <option value="" selected={@status_filter == ""}>--status=*</option>
                          <option value="up" selected={@status_filter == "up"}>--status=up</option>
                          <option value="down" selected={@status_filter == "down"}>
                            --status=down
                          </option>
                        </select>
                      </form>
                    </div>
                  </div>
                  <div class="project-card-body !p-0">
                    <div :if={@results == []} class="project-empty-state py-8">
                      <.icon name="hero-inbox" class="size-10 opacity-20" />
                      <span class="mt-2">No results yet</span>
                    </div>
                    <div :if={@results != []}>
                      <%!-- Results table header --%>
                      <div class="hidden sm:flex items-center gap-4 px-4 py-2 border-b border-base-300/30 text-xs font-mono text-muted uppercase">
                        <div class="w-14">Status</div>
                        <div class="w-14">HTTP</div>
                        <div class="w-16">Time</div>
                        <div class="flex-1">Error</div>
                        <div class="w-36">Checked At</div>
                      </div>
                      <%!-- Results rows --%>
                      <%= for result <- @results do %>
                        <div class="flex items-center gap-4 px-4 py-3 border-b border-base-300/20 last:border-b-0 text-sm">
                          <div class="w-14">
                            <%= if result.status == :up do %>
                              <span class="status-badge status-badge-active">UP</span>
                            <% else %>
                              <span class="status-badge status-badge-error">DOWN</span>
                            <% end %>
                          </div>
                          <div class="w-14 font-mono text-xs text-muted">
                            {result.status_code || "-"}
                          </div>
                          <div class="w-16 font-mono text-xs text-muted">
                            {if result.response_ms, do: "#{result.response_ms}ms", else: "-"}
                          </div>
                          <div class="flex-1 font-mono text-xs text-error truncate">
                            {result.error || ""}
                          </div>
                          <div class="w-36 font-mono text-xs text-muted">
                            {format_datetime(result.checked_at)}
                          </div>
                        </div>
                      <% end %>
                    </div>

                    <%!-- Results pagination --%>
                    <div
                      :if={@results_total > 0}
                      class="px-4 py-3 border-t border-base-300/50 flex items-center justify-between"
                    >
                      <span class="font-mono text-xs text-muted">
                        [{@results_page * @results_per_page - @results_per_page + 1}-{min(
                          @results_page * @results_per_page,
                          @results_total
                        )}] of {@results_total}
                      </span>

                      <div :if={@results_total_pages > 1} class="flex items-center gap-2">
                        <.link
                          :if={@results_page > 1}
                          patch={
                            results_path(
                              @current_scope.account.slug,
                              @project.id,
                              @check.id,
                              @status_filter,
                              @results_page - 1
                            )
                          }
                          class="btn-subtle py-1.5 px-3 font-mono text-xs"
                        >
                          <.icon name="hero-chevron-left" class="size-3.5" />
                        </.link>
                        <span class="font-mono text-xs text-muted px-2">
                          {@results_page}/{@results_total_pages}
                        </span>
                        <.link
                          :if={@results_page < @results_total_pages}
                          patch={
                            results_path(
                              @current_scope.account.slug,
                              @project.id,
                              @check.id,
                              @status_filter,
                              @results_page + 1
                            )
                          }
                          class="btn-subtle py-1.5 px-3 font-mono text-xs"
                        >
                          <.icon name="hero-chevron-right" class="size-3.5" />
                        </.link>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <%!-- Sidebar: Configuration --%>
              <div class="lg:col-span-4 space-y-5">
                <div class="project-sidebar-card">
                  <div class="project-sidebar-header">
                    <.icon name="hero-cog-6-tooth" class="size-4" />
                    <span>Configuration</span>
                  </div>
                  <div class="project-sidebar-body">
                    <div class="project-detail-row">
                      <span class="project-detail-label">Method</span>
                      <span class="project-detail-value">{method_label(@check.method)}</span>
                    </div>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Interval</span>
                      <span class="project-detail-value">
                        {format_interval(@check.interval_seconds)}
                      </span>
                    </div>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Expected Status</span>
                      <span class="project-detail-value">{@check.expected_status}</span>
                    </div>
                    <div :if={@check.keyword} class="project-detail-row">
                      <span class="project-detail-label">Keyword</span>
                      <span class="project-detail-value font-mono text-xs">
                        {if @check.keyword_absence, do: "NOT ", else: ""}{@check.keyword}
                      </span>
                    </div>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Failure Threshold</span>
                      <span class="project-detail-value">{@check.failure_threshold}</span>
                    </div>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Reopen Window</span>
                      <span class="project-detail-value">{@check.reopen_window_hours}h</span>
                    </div>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Consecutive Failures</span>
                      <span class="project-detail-value">{@check.consecutive_failures}</span>
                    </div>
                  </div>
                </div>

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
                            {format_datetime(@check.inserted_at)}
                          </span>
                        </div>
                      </div>
                      <div class="project-timeline-item">
                        <div class="project-timeline-dot project-timeline-dot-updated"></div>
                        <div class="project-timeline-content">
                          <span class="project-timeline-label">Last Checked</span>
                          <span class="project-timeline-value">
                            {format_datetime(@check.last_checked_at)}
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
          <span>Read-only access. Contact an admin to modify this check.</span>
        </div>
      </div>

      <%!-- Edit Modal --%>
      <.modal
        :if={@live_action == :edit}
        id="check-modal"
        show
        title="Edit Check"
        on_cancel={
          JS.patch(
            ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks/#{@check.id}"
          )
        }
      >
        <div class="space-y-5">
          <.form
            for={@form}
            id="check-edit-form"
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
                />

                <.input
                  field={@form[:reopen_window_hours]}
                  type="number"
                  label="Reopen Window (hours)"
                  min="1"
                />
              </div>

              <.input
                field={@form[:paused]}
                type="checkbox"
                label="Paused"
              />
            </div>

            <div class="modal-action">
              <.link
                patch={
                  ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/checks/#{@check.id}"
                }
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
