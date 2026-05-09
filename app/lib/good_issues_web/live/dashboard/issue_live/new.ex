defmodule GIWeb.Dashboard.IssueLive.New do
  @moduledoc """
  Dashboard view for creating a new issue.

  Only users with owner/admin role can create issues.
  """
  use GIWeb, :live_view

  alias GI.Accounts.Scope
  alias GI.Tracking
  alias GI.Tracking.Issue

  @impl true
  def mount(_params, _session, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      account = socket.assigns.current_scope.account
      projects = Tracking.list_projects(account)

      {:ok,
       socket
       |> assign(:page_title, "New Issue")
       |> assign(:projects, projects)
       |> assign(:issue, %Issue{})}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to create issues.")
       |> push_navigate(to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/issues")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({GIWeb.Dashboard.IssueLive.FormComponent, {:saved, _issue}}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <GIWeb.Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      active_nav={:issues}
    >
      <div class="h-full flex flex-col">
        <%!-- Page header --%>
        <div class="px-4 sm:px-6 py-4 sm:py-5 border-b border-base-300/50 bg-base-100">
          <div class="flex items-center gap-3 sm:gap-4">
            <.link
              navigate={~p"/dashboard/#{@current_scope.account.slug}/issues"}
              class="size-9 sm:size-10 rounded-sm bg-base-200 border border-base-300 flex items-center justify-center hover:bg-base-300 transition-colors"
            >
              <.icon name="hero-arrow-left" class="size-4 sm:size-5 text-muted" />
            </.link>
            <div>
              <h1 class="text-base sm:text-lg font-semibold text-base-content">New Issue</h1>
              <div class="font-mono text-[11px] sm:text-xs text-muted mt-0.5">
                Create a new issue for {@current_scope.account.name}
              </div>
            </div>
          </div>
        </div>

        <%!-- Form content --%>
        <div class="flex-1 overflow-auto px-4 sm:px-6 py-6">
          <div class="max-w-2xl">
            <%= if Enum.empty?(@projects) do %>
              <div class="terminal-card p-6">
                <div class="flex flex-col items-center text-center">
                  <div class="size-16 rounded-sm bg-base-200 border border-base-300 flex items-center justify-center mb-4">
                    <.icon name="hero-folder" class="size-8 opacity-30" />
                  </div>
                  <div class="font-mono text-sm mb-2">No projects found</div>
                  <div class="font-mono text-xs text-muted mb-4">
                    You need to create a project before you can create issues.
                  </div>
                  <.link
                    navigate={~p"/dashboard/#{@current_scope.account.slug}"}
                    class="btn-primary py-2 px-4 font-mono text-sm"
                  >
                    Go to Dashboard
                  </.link>
                </div>
              </div>
            <% else %>
              <div class="terminal-card p-6">
                <.live_component
                  module={GIWeb.Dashboard.IssueLive.FormComponent}
                  id={:new}
                  title="Create Issue"
                  action={:new}
                  issue={@issue}
                  projects={@projects}
                  current_scope={@current_scope}
                  patch={~p"/dashboard/#{@current_scope.account.slug}/issues"}
                />
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </GIWeb.Layouts.dashboard>
    """
  end
end
