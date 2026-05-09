defmodule GIWeb.Dashboard.ProjectLive.New do
  @moduledoc """
  Dashboard view for creating a new project.

  Only users with owner/admin role can create projects.
  """
  use GIWeb, :live_view

  alias GI.Accounts.Scope
  alias GI.Tracking
  alias GI.Tracking.Project

  @impl true
  def mount(_params, _session, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      changeset =
        Tracking.change_new_project(%Project{account_id: socket.assigns.current_scope.account.id})

      {:ok,
       socket
       |> assign(:page_title, "New Project")
       |> assign(:form, to_form(changeset))
       |> assign(:suggested_prefix, "")}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to create projects.")
       |> push_navigate(to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/projects")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"project" => project_params}, socket) do
    account = socket.assigns.current_scope.account

    # Suggest prefix when name changes
    suggested_prefix =
      case project_params["name"] do
        nil -> ""
        "" -> ""
        name -> Tracking.suggest_prefix(name)
      end

    changeset =
      %Project{account_id: account.id}
      |> Tracking.change_new_project(project_params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:suggested_prefix, suggested_prefix)}
  end

  @impl true
  def handle_event("save", %{"project" => project_params}, socket) do
    account = socket.assigns.current_scope.account

    case Tracking.create_project(account, project_params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project created successfully.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/projects/#{project.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("use_suggested_prefix", _params, socket) do
    current_params = socket.assigns.form.params || %{}
    updated_params = Map.put(current_params, "prefix", socket.assigns.suggested_prefix)

    account = socket.assigns.current_scope.account

    changeset =
      %Project{account_id: account.id}
      |> Tracking.change_new_project(updated_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  defp prefix_preview(form) do
    case form.params["prefix"] do
      nil -> "PRJ"
      "" -> "PRJ"
      prefix -> String.upcase(prefix)
    end
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
        <%!-- Page header --%>
        <div class="px-4 sm:px-6 py-4 sm:py-5 border-b border-base-300/50 bg-base-100">
          <div class="flex items-center gap-3 sm:gap-4">
            <.link
              navigate={~p"/dashboard/#{@current_scope.account.slug}/projects"}
              class="size-9 sm:size-10 rounded-sm bg-base-200 border border-base-300 flex items-center justify-center hover:bg-base-300 transition-colors"
              aria-label="Back to projects"
            >
              <.icon name="hero-arrow-left" class="size-4 sm:size-5 text-muted" />
            </.link>
            <div>
              <h1 class="text-base sm:text-lg font-semibold text-base-content">New Project</h1>
              <div class="font-mono text-[11px] sm:text-xs text-muted mt-0.5">
                Create a new project for {@current_scope.account.name}
              </div>
            </div>
          </div>
        </div>

        <%!-- Form content --%>
        <div class="flex-1 overflow-auto px-4 sm:px-6 py-6">
          <div class="max-w-2xl">
            <div class="terminal-card p-6">
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
                      phx-debounce="300"
                    />
                  </div>

                  <%!-- Prefix field --%>
                  <div>
                    <label for={@form[:prefix].id} class="label font-mono text-xs uppercase">
                      Prefix <span class="text-error">*</span>
                    </label>
                    <div class="flex items-center gap-2">
                      <.input
                        field={@form[:prefix]}
                        type="text"
                        placeholder="PRJ"
                        maxlength="10"
                        class="input-field font-mono uppercase flex-1"
                      />
                      <button
                        :if={@suggested_prefix != "" && @form.params["prefix"] != @suggested_prefix}
                        type="button"
                        phx-click="use_suggested_prefix"
                        class="btn-subtle py-2 px-3 font-mono text-xs whitespace-nowrap"
                      >
                        Use "{@suggested_prefix}"
                      </button>
                    </div>
                    <p class="mt-1 text-xs text-muted font-mono">
                      1-10 uppercase letters and numbers. Used for issue IDs like {prefix_preview(
                        @form
                      )}-123.
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
                      navigate={~p"/dashboard/#{@current_scope.account.slug}/projects"}
                      class="btn-subtle py-2 px-4 font-mono text-sm"
                    >
                      Cancel
                    </.link>
                    <button type="submit" class="btn-primary py-2 px-4 font-mono text-sm">
                      Create Project
                    </button>
                  </div>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </GIWeb.Layouts.dashboard>
    """
  end
end
