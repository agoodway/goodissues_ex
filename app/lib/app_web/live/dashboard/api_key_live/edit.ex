defmodule FFWeb.Dashboard.ApiKeyLive.Edit do
  @moduledoc """
  Dashboard view for editing an API key's scopes.

  Only users with owner/admin role can edit API keys.
  Revoked keys cannot be edited.
  """
  use FFWeb, :live_view

  alias FF.Accounts
  alias FF.Accounts.Scope

  @available_scopes [
    {"projects:read", "Read access to projects"},
    {"projects:write", "Write access to projects"},
    {"issues:read", "Read access to issues"},
    {"issues:write", "Write access to issues"},
    {"errors:read", "Read access to errors"},
    {"errors:write", "Write access to errors"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      {:ok, assign(socket, :available_scopes, @available_scopes)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to edit API keys.")
       |> push_navigate(to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/api-keys")}
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    account = socket.assigns.current_scope.account

    case Accounts.get_account_api_key(account, id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "API key not found.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/api-keys")}

      %{status: :revoked} = api_key ->
        {:noreply,
         socket
         |> put_flash(:error, "Cannot edit a revoked API key.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/api-keys/#{api_key.id}")}

      api_key ->
        changeset = Accounts.change_api_key_scopes(api_key)

        {:noreply,
         socket
         |> assign(:page_title, "Edit #{api_key.name}")
         |> assign(:api_key, api_key)
         |> assign(:selected_scopes, MapSet.new(api_key.scopes))
         |> assign(:form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("toggle_scope", %{"scope" => scope}, socket) do
    selected_scopes = socket.assigns.selected_scopes

    selected_scopes =
      if MapSet.member?(selected_scopes, scope) do
        MapSet.delete(selected_scopes, scope)
      else
        MapSet.put(selected_scopes, scope)
      end

    {:noreply, assign(socket, :selected_scopes, selected_scopes)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      account = socket.assigns.current_scope.account
      actor = socket.assigns.current_scope.account_user
      api_key = socket.assigns.api_key
      scopes = MapSet.to_list(socket.assigns.selected_scopes)

      case Accounts.update_api_key(account, actor, api_key.id, %{scopes: scopes}) do
        {:ok, _updated_api_key} ->
          {:noreply,
           socket
           |> put_flash(:info, "API key scopes updated successfully.")
           |> push_navigate(to: ~p"/dashboard/#{account.slug}/api-keys/#{api_key.id}")}

        {:error, :revoked} ->
          {:noreply,
           socket
           |> put_flash(:error, "Cannot edit a revoked API key.")
           |> push_navigate(to: ~p"/dashboard/#{account.slug}/api-keys/#{api_key.id}")}

        {:error, :not_found} ->
          {:noreply,
           socket
           |> put_flash(:error, "API key not found.")
           |> push_navigate(to: ~p"/dashboard/#{account.slug}/api-keys")}

        {:error, :not_authorized} ->
          {:noreply,
           socket
           |> put_flash(:error, "You don't have permission to edit this API key.")
           |> push_navigate(to: ~p"/dashboard/#{account.slug}/api-keys/#{api_key.id}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset))}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to edit API keys.")
       |> push_navigate(to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/api-keys")}
    end
  end

  defp scope_resource(scope) do
    scope |> String.split(":") |> List.first()
  end

  defp scope_icon(scope) do
    case scope_resource(scope) do
      "projects" -> "hero-folder"
      "issues" -> "hero-exclamation-triangle"
      "errors" -> "hero-bug-ant"
      _ -> "hero-key"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <FFWeb.Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      active_nav={:api_keys}
    >
      <style>
        .edit-panel {
          position: relative;
          background: oklch(7% 0.008 270);
          border: 1px solid oklch(15% 0.012 270);
        }
        .edit-panel::before {
          content: '';
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          height: 2px;
          background: linear-gradient(90deg, oklch(80% 0.18 145 / 0.6), oklch(75% 0.15 200 / 0.4), transparent);
        }
        [data-theme="light"] .edit-panel {
          background: oklch(99% 0.003 90);
          border-color: oklch(88% 0.01 90);
        }
        [data-theme="light"] .edit-panel::before {
          background: linear-gradient(90deg, oklch(50% 0.2 145 / 0.5), oklch(50% 0.18 200 / 0.3), transparent);
        }
        .key-info-bar {
          display: flex;
          flex-wrap: wrap;
          align-items: center;
          gap: 0.75rem 1.25rem;
          padding: 0.875rem 1rem;
          background: oklch(10% 0.01 270);
          border: 1px solid oklch(18% 0.012 270);
          font-family: 'JetBrains Mono', monospace;
          font-size: 0.75rem;
        }
        @media (max-width: 480px) {
          .key-info-bar {
            flex-direction: column;
            align-items: flex-start;
            gap: 0.5rem;
          }
          .key-info-bar .divider-line { display: none; }
        }
        [data-theme="light"] .key-info-bar {
          background: oklch(96% 0.006 90);
          border-color: oklch(88% 0.01 90);
        }
        .permission-card {
          position: relative;
          padding: 1rem 1rem;
          background: oklch(8% 0.008 270);
          border: 1px solid oklch(15% 0.01 270);
          cursor: pointer;
          transition: all 0.15s ease-out;
          -webkit-tap-highlight-color: transparent;
        }
        @media (max-width: 480px) {
          .permission-card {
            padding: 1rem 0.875rem;
          }
        }
        .permission-card:hover {
          background: oklch(10% 0.01 270);
          border-color: oklch(20% 0.012 270);
        }
        .permission-card.selected {
          border-color: oklch(80% 0.18 145 / 0.5);
          background: oklch(80% 0.18 145 / 0.08);
        }
        .permission-card.selected::before {
          content: '';
          position: absolute;
          left: 0;
          top: 0;
          bottom: 0;
          width: 3px;
          background: oklch(80% 0.18 145);
        }
        [data-theme="light"] .permission-card {
          background: oklch(98% 0.004 90);
          border-color: oklch(90% 0.008 90);
        }
        [data-theme="light"] .permission-card:hover {
          background: oklch(96% 0.006 90);
          border-color: oklch(85% 0.01 90);
        }
        [data-theme="light"] .permission-card.selected {
          border-color: oklch(50% 0.2 145 / 0.5);
          background: oklch(50% 0.2 145 / 0.06);
        }
        [data-theme="light"] .permission-card.selected::before {
          background: oklch(50% 0.2 145);
        }
        .permission-toggle {
          width: 18px;
          height: 18px;
          border: 2px solid oklch(30% 0.01 270);
          background: transparent;
          display: flex;
          align-items: center;
          justify-content: center;
          flex-shrink: 0;
          transition: all 0.15s ease-out;
        }
        .permission-toggle.checked {
          border-color: oklch(80% 0.18 145);
          background: oklch(80% 0.18 145);
        }
        [data-theme="light"] .permission-toggle {
          border-color: oklch(75% 0.01 270);
        }
        [data-theme="light"] .permission-toggle.checked {
          border-color: oklch(50% 0.2 145);
          background: oklch(50% 0.2 145);
        }
        .scope-label {
          font-family: 'JetBrains Mono', monospace;
          font-size: 0.75rem;
          font-weight: 600;
          letter-spacing: 0.02em;
        }
        .scope-desc {
          font-size: 0.6875rem;
          color: oklch(55% 0.01 270);
          margin-top: 0.125rem;
        }
        [data-theme="light"] .scope-desc {
          color: oklch(50% 0.01 270);
        }
        .section-header {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          padding: 0.5rem 0.75rem;
          font-family: 'JetBrains Mono', monospace;
          font-size: 0.625rem;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: 0.1em;
          margin-bottom: 0.5rem;
        }
        .section-header.read-header {
          color: oklch(70% 0.15 240);
          background: oklch(70% 0.15 240 / 0.1);
          border-left: 3px solid oklch(70% 0.15 240);
        }
        .section-header.write-header {
          color: oklch(85% 0.18 85);
          background: oklch(85% 0.18 85 / 0.1);
          border-left: 3px solid oklch(85% 0.18 85);
        }
        [data-theme="light"] .section-header.read-header {
          color: oklch(45% 0.18 240);
          background: oklch(50% 0.18 240 / 0.08);
          border-left-color: oklch(50% 0.18 240);
        }
        [data-theme="light"] .section-header.write-header {
          color: oklch(45% 0.2 85);
          background: oklch(55% 0.2 85 / 0.08);
          border-left-color: oklch(55% 0.2 85);
        }
        .summary-bar {
          display: flex;
          align-items: center;
          justify-content: space-between;
          flex-wrap: wrap;
          gap: 1rem;
          padding: 1.25rem 1.5rem;
          background: oklch(10% 0.01 270);
          border: 1px solid oklch(18% 0.012 270);
          border-top: 2px solid oklch(80% 0.18 145 / 0.5);
        }
        @media (max-width: 640px) {
          .summary-bar {
            flex-direction: column;
            align-items: stretch;
            gap: 1rem;
            padding: 1rem;
          }
          .summary-bar .summary-left {
            justify-content: space-between;
          }
          .summary-bar .summary-right {
            display: flex;
            gap: 0.75rem;
          }
          .summary-bar .summary-right > * {
            flex: 1;
            justify-content: center;
          }
        }
        [data-theme="light"] .summary-bar {
          background: oklch(96% 0.006 90);
          border-color: oklch(88% 0.01 90);
          border-top-color: oklch(50% 0.2 145 / 0.5);
        }
        .count-badge {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          min-width: 1.5rem;
          height: 1.5rem;
          padding: 0 0.5rem;
          font-family: 'JetBrains Mono', monospace;
          font-size: 0.6875rem;
          font-weight: 700;
          background: oklch(80% 0.18 145);
          color: oklch(10% 0.02 145);
        }
        [data-theme="light"] .count-badge {
          background: oklch(50% 0.2 145);
          color: oklch(98% 0.01 145);
        }
        .scope-chip {
          display: inline-flex;
          align-items: center;
          gap: 0.375rem;
          padding: 0.3125rem 0.625rem;
          font-family: 'JetBrains Mono', monospace;
          font-size: 0.6875rem;
          font-weight: 500;
          background: oklch(15% 0.01 270);
          border: 1px solid oklch(20% 0.012 270);
          color: oklch(70% 0.01 270);
        }
        [data-theme="light"] .scope-chip {
          background: oklch(94% 0.006 90);
          border-color: oklch(88% 0.01 90);
          color: oklch(40% 0.01 270);
        }
        .scope-chip.scope-read {
          border-color: oklch(70% 0.15 240 / 0.4);
          color: oklch(70% 0.15 240);
        }
        .scope-chip.scope-write {
          border-color: oklch(85% 0.18 85 / 0.4);
          color: oklch(85% 0.18 85);
        }
        [data-theme="light"] .scope-chip.scope-read {
          border-color: oklch(50% 0.18 240 / 0.4);
          color: oklch(45% 0.18 240);
        }
        [data-theme="light"] .scope-chip.scope-write {
          border-color: oklch(55% 0.2 85 / 0.4);
          color: oklch(45% 0.2 85);
        }
        @keyframes check-in {
          0% { transform: scale(0); }
          50% { transform: scale(1.2); }
          100% { transform: scale(1); }
        }
        .check-icon {
          animation: check-in 0.2s ease-out;
        }
      </style>

      <%!-- Navigation breadcrumb --%>
      <div class="flex items-center gap-2 mb-6 text-sm">
        <.link
          navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys"}
          class="text-muted hover:text-base-content transition-colors flex items-center gap-1.5"
        >
          <.icon name="hero-key" class="size-4" />
          <span>API Keys</span>
        </.link>
        <span class="text-muted">/</span>
        <.link
          navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/#{@api_key.id}"}
          class="text-muted hover:text-base-content transition-colors"
        >
          <span class="font-mono text-xs">{@api_key.name}</span>
        </.link>
        <span class="text-muted">/</span>
        <span class="font-mono text-xs">Edit</span>
      </div>

      <%!-- Page Header --%>
      <div class="mb-4 sm:mb-6">
        <div class="flex items-center gap-3 mb-2">
          <div class="w-9 h-9 sm:w-10 sm:h-10 flex items-center justify-center bg-primary/15 text-primary flex-shrink-0">
            <.icon name="hero-shield-check" class="size-4 sm:size-5" />
          </div>
          <div class="min-w-0">
            <h1 class="text-lg sm:text-xl font-semibold tracking-tight">Edit Permissions</h1>
            <p class="text-xs sm:text-sm text-muted">Configure API access scopes for this key</p>
          </div>
        </div>
      </div>

      <%!-- Key Info Bar --%>
      <div class="key-info-bar mb-4 sm:mb-6">
        <div class="flex items-center gap-2">
          <.icon name={if @api_key.type == :private, do: "hero-lock-closed", else: "hero-globe-alt"} class="size-4 text-muted" />
          <span class="text-primary font-semibold">{@api_key.name}</span>
        </div>
        <div class="divider-line h-4 w-px bg-base-300 hidden sm:block"></div>
        <div class="flex items-center gap-2">
          <span class="text-muted">token:</span>
          <span class="text-primary">{@api_key.token_prefix}...</span>
        </div>
        <div class="divider-line h-4 w-px bg-base-300 hidden sm:block"></div>
        <div class="flex items-center gap-2">
          <span class="text-muted">type:</span>
          <span class={[
            @api_key.type == :private && "text-warning",
            @api_key.type == :public && "text-info"
          ]}>
            {@api_key.type}
          </span>
        </div>
        <div class="hidden md:flex items-center gap-2 sm:ml-auto">
          <span class="text-muted">owner:</span>
          <span class="truncate max-w-48">{@api_key.account_user.user.email}</span>
        </div>
      </div>

      <.form for={@form} id="edit-api-key-form" phx-submit="save">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-3 sm:gap-4 mb-3 sm:mb-4">
          <%!-- Read Permissions --%>
          <div class="edit-panel p-3 sm:p-4">
            <div class="section-header read-header">
              <.icon name="hero-eye" class="size-3.5" />
              <span>Read Permissions</span>
            </div>
            <div class="space-y-2">
              <%= for {scope, description} <- @available_scopes, String.ends_with?(scope, ":read") do %>
                <label class={[
                  "permission-card block",
                  MapSet.member?(@selected_scopes, scope) && "selected"
                ]}>
                  <input
                    type="checkbox"
                    class="sr-only"
                    checked={MapSet.member?(@selected_scopes, scope)}
                    phx-click="toggle_scope"
                    phx-value-scope={scope}
                  />
                  <div class="flex items-start gap-3">
                    <div class={[
                      "permission-toggle mt-0.5",
                      MapSet.member?(@selected_scopes, scope) && "checked"
                    ]}>
                      <%= if MapSet.member?(@selected_scopes, scope) do %>
                        <.icon name="hero-check" class="size-3 text-primary-content check-icon" />
                      <% end %>
                    </div>
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-2">
                        <.icon name={scope_icon(scope)} class="size-3.5 text-muted" />
                        <span class="scope-label">{scope}</span>
                      </div>
                      <div class="scope-desc">{description}</div>
                    </div>
                  </div>
                </label>
              <% end %>
            </div>
          </div>

          <%!-- Write Permissions --%>
          <div class="edit-panel p-3 sm:p-4">
            <div class="section-header write-header">
              <.icon name="hero-pencil" class="size-3.5" />
              <span>Write Permissions</span>
            </div>
            <div class="space-y-2">
              <%= for {scope, description} <- @available_scopes, String.ends_with?(scope, ":write") do %>
                <label class={[
                  "permission-card block",
                  MapSet.member?(@selected_scopes, scope) && "selected"
                ]}>
                  <input
                    type="checkbox"
                    class="sr-only"
                    checked={MapSet.member?(@selected_scopes, scope)}
                    phx-click="toggle_scope"
                    phx-value-scope={scope}
                  />
                  <div class="flex items-start gap-3">
                    <div class={[
                      "permission-toggle mt-0.5",
                      MapSet.member?(@selected_scopes, scope) && "checked"
                    ]}>
                      <%= if MapSet.member?(@selected_scopes, scope) do %>
                        <.icon name="hero-check" class="size-3 text-primary-content check-icon" />
                      <% end %>
                    </div>
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-2">
                        <.icon name={scope_icon(scope)} class="size-3.5 text-muted" />
                        <span class="scope-label">{scope}</span>
                      </div>
                      <div class="scope-desc">{description}</div>
                    </div>
                  </div>
                </label>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Summary Bar --%>
        <div class="summary-bar mb-4 sm:mb-6">
          <div class="summary-left flex items-center gap-5">
            <div class="flex items-center gap-3">
              <span class="font-mono text-xs font-semibold uppercase tracking-wider text-muted">Selected</span>
              <span class="count-badge">{MapSet.size(@selected_scopes)}</span>
            </div>

            <%= if MapSet.size(@selected_scopes) > 0 do %>
              <div class="hidden lg:flex flex-wrap gap-1.5">
                <%= for scope <- Enum.sort(MapSet.to_list(@selected_scopes)) do %>
                  <span class={[
                    "scope-chip",
                    String.contains?(scope, "read") && "scope-read",
                    String.contains?(scope, "write") && "scope-write"
                  ]}>
                    {scope}
                  </span>
                <% end %>
              </div>
            <% else %>
              <span class="text-xs text-muted hidden sm:inline">All operations allowed</span>
            <% end %>
          </div>

          <div class="summary-right flex items-stretch gap-3 sm:gap-4">
            <.link
              navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/#{@api_key.id}"}
              class="btn-subtle text-xs px-4 sm:px-5 flex items-center justify-center"
              style="min-height: 2.75rem;"
            >
              Cancel
            </.link>
            <button
              type="submit"
              class="btn-action text-xs px-4 sm:px-5 flex items-center justify-center gap-2"
              style="min-height: 2.75rem;"
              phx-disable-with="Saving..."
            >
              <.icon name="hero-check" class="size-3.5" />
              <span>Save</span>
            </button>
          </div>
        </div>

        <%!-- Info Notice --%>
        <div :if={MapSet.size(@selected_scopes) == 0} class="edit-panel p-4 border-l-2 border-l-info">
          <div class="flex items-start gap-3">
            <.icon name="hero-information-circle" class="size-5 text-info flex-shrink-0 mt-0.5" />
            <div>
              <div class="text-sm font-medium">No Scope Restrictions</div>
              <div class="text-xs text-muted mt-1">
                When no scopes are selected, this API key has access to all operations allowed by its type
                (<%= if @api_key.type == :private, do: "read and write", else: "read only" %>).
                Select specific scopes above to restrict access.
              </div>
            </div>
          </div>
        </div>
      </.form>
    </FFWeb.Layouts.dashboard>
    """
  end
end
