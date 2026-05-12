defmodule GIWeb.Dashboard.HeartbeatLive.Show do
  @moduledoc """
  Dashboard view for showing a single heartbeat with edit modal,
  delete, ping URL reveal, and paginated/filterable ping history.
  """
  use GIWeb, :live_view

  alias GI.Accounts.Scope
  alias GI.Monitoring
  alias GI.Monitoring.Heartbeat
  alias GI.Tracking

  import GIWeb.Dashboard.HeartbeatLive.Helpers

  @impl true
  def mount(%{"project_id" => project_id, "id" => heartbeat_id}, _session, socket) do
    account = socket.assigns.current_scope.account

    with %{} = project <- Tracking.get_project(account, project_id),
         %Heartbeat{} = heartbeat <- Monitoring.get_heartbeat(account, project_id, heartbeat_id) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(GI.PubSub, Monitoring.heartbeats_topic(project.id))
      end

      can_manage = Scope.can_manage_account?(socket.assigns.current_scope)

      {:ok,
       socket
       |> assign(:project, project)
       |> assign(:heartbeat, heartbeat)
       |> assign(:can_manage, can_manage)
       |> assign(:page_title, heartbeat.name)
       |> assign(:ping_url_revealed, false)
       |> assign(:ping_url, nil)}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Heartbeat not found.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, params) do
    load_pings(socket, params)
  end

  defp apply_action(socket, :edit, params) do
    socket = load_pings(socket, params)

    cond do
      not socket.assigns.can_manage ->
        socket
        |> put_flash(:error, "You don't have permission to edit heartbeats.")
        |> push_patch(
          to:
            ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/projects/#{socket.assigns.project.id}/heartbeats/#{socket.assigns.heartbeat.id}"
        )

      true ->
        changeset = Monitoring.change_heartbeat(socket.assigns.heartbeat)

        socket
        |> assign(:page_title, "Edit: #{socket.assigns.heartbeat.name}")
        |> assign(:form, to_form(changeset))
        |> assign(:show_advanced, true)
    end
  end

  defp load_pings(socket, params) do
    heartbeat = socket.assigns.heartbeat
    page = parse_page_param(params["pings_page"])
    kind_filter = params["kind"] || ""

    filters =
      %{page: page}
      |> maybe_add_filter(:kind, kind_filter)

    result = Monitoring.list_heartbeat_pings(heartbeat, filters)

    socket
    |> assign(:pings, result.pings)
    |> assign(:pings_page, result.page)
    |> assign(:pings_per_page, result.per_page)
    |> assign(:pings_total_pages, result.total_pages)
    |> assign(:pings_total, result.total)
    |> assign(:kind_filter, kind_filter)
  end

  defp maybe_add_filter(filters, _key, ""), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)

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
  def handle_event("reveal_ping_url", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      ping_url = Monitoring.reveal_ping_url(socket.assigns.heartbeat)

      {:noreply,
       socket
       |> assign(:ping_url_revealed, true)
       |> assign(:ping_url, ping_url)}
    else
      {:noreply, put_flash(socket, :error, "You don't have permission.")}
    end
  end

  @impl true
  def handle_event("filter_kind", %{"kind" => kind}, socket) do
    account_slug = socket.assigns.current_scope.account.slug
    project_id = socket.assigns.project.id
    heartbeat_id = socket.assigns.heartbeat.id

    params = if kind != "", do: %{kind: kind}, else: %{}

    {:noreply,
     push_patch(socket,
       to:
         ~p"/dashboard/#{account_slug}/projects/#{project_id}/heartbeats/#{heartbeat_id}?#{params}"
     )}
  end

  @impl true
  def handle_event("toggle_pause", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      heartbeat = socket.assigns.heartbeat

      case Monitoring.update_heartbeat(heartbeat, %{paused: !heartbeat.paused}) do
        {:ok, updated} ->
          {:noreply, assign(socket, :heartbeat, updated)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update heartbeat.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission.")}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      case Monitoring.delete_heartbeat(socket.assigns.heartbeat) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Heartbeat deleted.")
           |> push_navigate(
             to:
               ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/projects/#{socket.assigns.project.id}/heartbeats"
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete heartbeat.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission.")}
    end
  end

  @impl true
  def handle_event("validate", %{"heartbeat" => heartbeat_params}, socket) do
    changeset =
      socket.assigns.heartbeat
      |> Monitoring.change_heartbeat(heartbeat_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"heartbeat" => heartbeat_params}, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      case Monitoring.update_heartbeat(socket.assigns.heartbeat, heartbeat_params) do
        {:ok, updated} ->
          {:noreply,
           socket
           |> assign(:heartbeat, updated)
           |> put_flash(:info, "Heartbeat updated.")
           |> push_patch(
             to:
               ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/projects/#{socket.assigns.project.id}/heartbeats/#{updated.id}"
           )}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission.")}
    end
  end

  # PubSub handlers

  @impl true
  def handle_info({event, payload}, socket)
      when event in [:heartbeat_updated, :heartbeat_status_changed] do
    if payload.id == socket.assigns.heartbeat.id do
      {:noreply, assign(socket, :heartbeat, struct(socket.assigns.heartbeat, payload))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:heartbeat_ping_received, payload}, socket) do
    if payload.heartbeat_id == socket.assigns.heartbeat.id do
      heartbeat =
        struct(socket.assigns.heartbeat, %{
          status: payload.status,
          last_ping_at: payload.last_ping_at,
          next_due_at: payload.next_due_at,
          paused: payload.paused
        })

      socket = assign(socket, :heartbeat, heartbeat)

      # Prepend ping to history if on page 1 and matches filter
      socket = prepend_ping(socket, payload.ping)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:heartbeat_deleted, %{id: id}}, socket) do
    if id == socket.assigns.heartbeat.id do
      {:noreply,
       socket
       |> put_flash(:info, "This heartbeat was deleted.")
       |> push_navigate(
         to:
           ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/projects/#{socket.assigns.project.id}/heartbeats"
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp prepend_ping(socket, ping) do
    matches_filter = ping_matches_filter?(ping, socket.assigns.kind_filter)

    if not matches_filter do
      socket
    else
      total = socket.assigns.pings_total + 1
      total_pages = max(ceil(total / socket.assigns.pings_per_page), 1)

      if socket.assigns.pings_page != 1 do
        socket
        |> assign(:pings_total, total)
        |> assign(:pings_total_pages, total_pages)
      else
        pings =
          [ping | socket.assigns.pings]
          |> Enum.take(socket.assigns.pings_per_page)

        socket
        |> assign(:pings, pings)
        |> assign(:pings_total, total)
        |> assign(:pings_total_pages, total_pages)
      end
    end
  end

  defp ping_matches_filter?(_ping, ""), do: true

  defp ping_matches_filter?(%{kind: kind}, filter) do
    to_string(kind) == filter
  end

  # Helpers

  defp format_datetime(nil), do: "-"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  defp kind_label(:ping), do: "PING"
  defp kind_label(:start), do: "START"
  defp kind_label(:fail), do: "FAIL"
  defp kind_label(kind), do: kind |> to_string() |> String.upcase()

  defp kind_class(:ping), do: "status-badge-active"
  defp kind_class(:start), do: "status-badge-info"
  defp kind_class(:fail), do: "status-badge-error"
  defp kind_class(_), do: "status-badge-muted"

  defp pings_path(account_slug, project_id, heartbeat_id, kind, page) do
    params =
      %{kind: kind, pings_page: page}
      |> Enum.reject(fn {_k, v} -> v == "" or v == 1 end)

    ~p"/dashboard/#{account_slug}/projects/#{project_id}/heartbeats/#{heartbeat_id}?#{params}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <GIWeb.Layouts.dashboard
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
                  ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/heartbeats"
                }
                class="font-mono text-xs text-base-content/50 hover:text-base-content transition-colors"
              >
                Heartbeats
              </.link>
              <span class="text-base-content/20 font-mono">/</span>
              <%= if @live_action == :edit do %>
                <.link
                  navigate={~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/heartbeats/#{@heartbeat.id}"}
                  class="font-mono text-xs text-base-content/50 hover:text-base-content transition-colors"
                >
                  {@heartbeat.name}
                </.link>
                <span class="text-base-content/20 font-mono">/</span>
                <span class="font-mono text-xs text-base-content/50">Edit</span>
              <% else %>
                <span class="font-mono text-xs text-base-content/50">{@heartbeat.name}</span>
              <% end %>
            </div>

            <%!-- Heartbeat identity --%>
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-3 mb-2">
                  <% {color, label} = display_status(@heartbeat) %>
                  <span class={["size-3 rounded-full", color]}></span>
                  <span class="font-mono text-xs text-muted">{label}</span>
                </div>

                <h1 class="project-title">{@heartbeat.name}</h1>

                <div class="flex flex-wrap items-center gap-3 mt-3">
                  <div class="project-stat-indicator">
                    <.icon name="hero-clock" class="size-3.5" />
                    <span>Every {format_interval(@heartbeat.interval_seconds)}</span>
                  </div>
                  <div :if={@heartbeat.grace_seconds > 0} class="project-meta-divider"></div>
                  <div :if={@heartbeat.grace_seconds > 0} class="project-meta-item">
                    <.icon name="hero-shield-check" class="size-3.5" />
                    <span>Grace: {format_interval(@heartbeat.grace_seconds)}</span>
                  </div>
                  <div class="project-meta-divider"></div>
                  <div class="project-meta-item">
                    <.icon name="hero-arrow-path" class="size-3.5" />
                    <span>Last: {format_relative_time(@heartbeat.last_ping_at)}</span>
                  </div>
                </div>
              </div>

              <%!-- Action buttons --%>
              <div :if={@can_manage} class="flex items-center gap-2 shrink-0">
                <button
                  phx-click="toggle_pause"
                  class="project-action-btn project-action-edit"
                >
                  <%= if @heartbeat.paused do %>
                    <.icon name="hero-play" class="size-4" />
                    <span class="hidden sm:inline">Resume</span>
                  <% else %>
                    <.icon name="hero-pause" class="size-4" />
                    <span class="hidden sm:inline">Pause</span>
                  <% end %>
                </button>
                <.link
                  patch={
                    ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/heartbeats/#{@heartbeat.id}/edit"
                  }
                  class="project-action-btn project-action-edit"
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                  <span class="hidden sm:inline">Edit</span>
                </.link>
                <button
                  phx-click="delete"
                  data-confirm="Are you sure you want to delete this heartbeat? All ping history will also be deleted. This cannot be undone."
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
              <%!-- Main content: Ping URL + Ping History --%>
              <div class="lg:col-span-8 space-y-6">
                <%!-- Ping URL card (manager only) --%>
                <div :if={@can_manage} class="project-card">
                  <div class="project-card-header">
                    <div class="project-card-header-icon">
                      <.icon name="hero-link" class="size-4" />
                    </div>
                    <span>Ping URL</span>
                  </div>
                  <div class="project-card-body">
                    <%= if @ping_url_revealed and @ping_url do %>
                      <div class="flex items-center gap-2 mb-2">
                        <span class="status-badge status-badge-info">POST</span>
                      </div>
                      <div class="flex items-center gap-2">
                        <input
                          type="text"
                          id="ping-url-input"
                          value={@ping_url}
                          readonly
                          class="input input-sm font-mono text-xs flex-1 bg-base-200"
                        />
                        <button
                          id="copy-ping-url"
                          phx-hook="CopyToClipboard"
                          data-copy-target="ping-url-input"
                          class="btn-subtle py-1.5 px-3 font-mono text-xs"
                        >
                          <.icon name="hero-clipboard" class="size-3.5 mr-1" /> Copy
                        </button>
                      </div>
                      <p class="font-mono text-[11px] text-muted mt-2">
                        Send a POST request to this URL to register a ping.
                        Append <code>/start</code> or <code>/fail</code> for job lifecycle signals.
                      </p>
                    <% else %>
                      <%= if @ping_url_revealed do %>
                        <p class="font-mono text-xs text-warning">
                          <.icon name="hero-exclamation-triangle" class="size-3.5 mr-1 inline" />
                          Ping URL is unavailable. The token may have been rotated.
                        </p>
                      <% else %>
                        <button
                          phx-click="reveal_ping_url"
                          class="btn-primary py-2 px-4 font-mono text-xs"
                        >
                          <.icon name="hero-eye" class="size-3.5 mr-1" /> Reveal Ping URL
                        </button>
                        <p class="font-mono text-[11px] text-muted mt-2">
                          The ping URL contains a secret token. Click to reveal.
                        </p>
                      <% end %>
                    <% end %>
                  </div>
                </div>

                <%!-- Ping history --%>
                <div class="project-card">
                  <div class="project-card-header">
                    <div class="project-card-header-icon">
                      <.icon name="hero-clipboard-document-list" class="size-4" />
                    </div>
                    <span>Ping History</span>
                    <div class="project-card-header-actions">
                      <form phx-change="filter_kind" class="flex items-center">
                        <select
                          name="kind"
                          class="select-minimal font-mono text-xs"
                          aria-label="Filter by kind"
                        >
                          <option value="" selected={@kind_filter == ""}>--kind=*</option>
                          <option value="ping" selected={@kind_filter == "ping"}>--kind=ping</option>
                          <option value="start" selected={@kind_filter == "start"}>
                            --kind=start
                          </option>
                          <option value="fail" selected={@kind_filter == "fail"}>--kind=fail</option>
                        </select>
                      </form>
                    </div>
                  </div>
                  <div class="project-card-body !p-0">
                    <div :if={@pings == []} class="project-empty-state py-8">
                      <.icon name="hero-inbox" class="size-10 opacity-20" />
                      <span class="mt-2">No pings yet</span>
                    </div>
                    <div :if={@pings != []}>
                      <%!-- Pings table header --%>
                      <div class="hidden sm:flex items-center gap-4 px-4 py-2 border-b border-base-300/30 text-xs font-mono text-muted uppercase">
                        <div class="w-16">Kind</div>
                        <div class="w-16">Duration</div>
                        <div class="w-14">Exit</div>
                        <div class="flex-1">Pinged At</div>
                      </div>
                      <%!-- Ping rows --%>
                      <%= for ping <- @pings do %>
                        <div class="flex items-center gap-4 px-4 py-3 border-b border-base-300/20 last:border-b-0 text-sm">
                          <div class="w-16">
                            <span class={["status-badge", kind_class(ping.kind)]}>
                              {kind_label(ping.kind)}
                            </span>
                          </div>
                          <div class="w-16 font-mono text-xs text-muted">
                            {if ping.duration_ms, do: "#{ping.duration_ms}ms", else: "-"}
                          </div>
                          <div class="w-14 font-mono text-xs text-muted">
                            {if ping.exit_code, do: ping.exit_code, else: "-"}
                          </div>
                          <div class="flex-1 font-mono text-xs text-muted">
                            {format_datetime(ping.pinged_at)}
                          </div>
                        </div>
                      <% end %>
                    </div>

                    <%!-- Pings pagination --%>
                    <div
                      :if={@pings_total > 0}
                      class="px-4 py-3 border-t border-base-300/50 flex items-center justify-between"
                    >
                      <span class="font-mono text-xs text-muted">
                        [{@pings_page * @pings_per_page - @pings_per_page + 1}-{min(
                          @pings_page * @pings_per_page,
                          @pings_total
                        )}] of {@pings_total}
                      </span>

                      <div :if={@pings_total_pages > 1} class="flex items-center gap-2">
                        <.link
                          :if={@pings_page > 1}
                          patch={
                            pings_path(
                              @current_scope.account.slug,
                              @project.id,
                              @heartbeat.id,
                              @kind_filter,
                              @pings_page - 1
                            )
                          }
                          class="btn-subtle py-1.5 px-3 font-mono text-xs"
                        >
                          <.icon name="hero-chevron-left" class="size-3.5" />
                        </.link>
                        <span class="font-mono text-xs text-muted px-2">
                          {@pings_page}/{@pings_total_pages}
                        </span>
                        <.link
                          :if={@pings_page < @pings_total_pages}
                          patch={
                            pings_path(
                              @current_scope.account.slug,
                              @project.id,
                              @heartbeat.id,
                              @kind_filter,
                              @pings_page + 1
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

              <%!-- Sidebar --%>
              <div class="lg:col-span-4 space-y-5">
                <div class="project-sidebar-card">
                  <div class="project-sidebar-header">
                    <.icon name="hero-cog-6-tooth" class="size-4" />
                    <span>Configuration</span>
                  </div>
                  <div class="project-sidebar-body">
                    <div class="project-detail-row">
                      <span class="project-detail-label">Interval</span>
                      <span class="project-detail-value">
                        {format_interval(@heartbeat.interval_seconds)}
                      </span>
                    </div>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Grace Period</span>
                      <span class="project-detail-value">
                        {format_interval(@heartbeat.grace_seconds)}
                      </span>
                    </div>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Failure Threshold</span>
                      <span class="project-detail-value">{@heartbeat.failure_threshold}</span>
                    </div>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Reopen Window</span>
                      <span class="project-detail-value">{@heartbeat.reopen_window_hours}h</span>
                    </div>
                    <div class="project-detail-row">
                      <span class="project-detail-label">Consecutive Failures</span>
                      <span class="project-detail-value">
                        {@heartbeat.consecutive_failures}
                      </span>
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
                            {format_datetime(@heartbeat.inserted_at)}
                          </span>
                        </div>
                      </div>
                      <div class="project-timeline-item">
                        <div class="project-timeline-dot project-timeline-dot-updated"></div>
                        <div class="project-timeline-content">
                          <span class="project-timeline-label">Last Ping</span>
                          <span class="project-timeline-value">
                            {format_datetime(@heartbeat.last_ping_at)}
                          </span>
                        </div>
                      </div>
                      <div :if={@heartbeat.next_due_at} class="project-timeline-item">
                        <div class="project-timeline-dot project-timeline-dot-updated"></div>
                        <div class="project-timeline-content">
                          <span class="project-timeline-label">Next Due</span>
                          <span class="project-timeline-value">
                            {format_datetime(@heartbeat.next_due_at)}
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
          <span>Read-only access. Contact an admin to modify this heartbeat.</span>
        </div>
      </div>

      <%!-- Edit Modal --%>
      <.modal
        :if={@live_action == :edit}
        id="heartbeat-modal"
        show
        title="Edit Heartbeat"
        on_cancel={
          JS.patch(
            ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/heartbeats/#{@heartbeat.id}"
          )
        }
      >
        <div class="space-y-5">
          <.form
            for={@form}
            id="heartbeat-edit-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <.input
              field={@form[:name]}
              type="text"
              label="Name"
              placeholder="Nightly Backup Job"
              required
            />

            <.input
              field={@form[:interval_seconds]}
              type="number"
              label="Interval (seconds)"
              min="30"
              max="86400"
            />

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
                field={@form[:grace_seconds]}
                type="number"
                label="Grace Period (seconds)"
                min="0"
                max="86400"
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
                  ~p"/dashboard/#{@current_scope.account.slug}/projects/#{@project.id}/heartbeats/#{@heartbeat.id}"
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
    </GIWeb.Layouts.dashboard>
    """
  end
end
