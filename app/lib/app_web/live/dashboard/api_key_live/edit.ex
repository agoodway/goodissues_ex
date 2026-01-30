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

  @impl true
  def render(assigns) do
    ~H"""
    <FFWeb.Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      active_nav={:api_keys}
    >
      <.header>
        Edit API Key Scopes
        <:subtitle>
          Modify permissions for <strong>{@api_key.name}</strong>
        </:subtitle>
      </.header>

      <div class="mt-6 max-w-2xl">
        <div class="card bg-base-200 mb-6">
          <div class="card-body">
            <h2 class="card-title text-base">API Key Details</h2>
            <div class="grid grid-cols-2 gap-4 text-sm">
              <div>
                <span class="text-base-content/60">Name:</span>
                <span class="ml-2 font-medium">{@api_key.name}</span>
              </div>
              <div>
                <span class="text-base-content/60">Type:</span>
                <span class={[
                  "badge badge-sm ml-2",
                  @api_key.type == :private && "badge-warning",
                  @api_key.type == :public && "badge-info"
                ]}>
                  {@api_key.type}
                </span>
              </div>
              <div>
                <span class="text-base-content/60">Token:</span>
                <code class="bg-base-300 px-2 py-0.5 rounded text-xs ml-2">
                  {@api_key.token_prefix}...
                </code>
              </div>
              <div>
                <span class="text-base-content/60">Owner:</span>
                <span class="ml-2">{@api_key.account_user.user.email}</span>
              </div>
            </div>
          </div>
        </div>

        <.form for={@form} id="edit-api-key-form" phx-submit="save">
          <div class="card bg-base-200">
            <div class="card-body">
              <h2 class="card-title text-base">Scopes</h2>
              <p class="text-sm text-base-content/60 mb-4">
                Select which operations this API key can perform. If no scopes are selected, the key
                will have access to all operations allowed by its type.
              </p>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div class="space-y-3">
                  <h3 class="font-medium text-sm text-base-content/70">Read Permissions</h3>
                  <%= for {scope, description} <- @available_scopes, String.ends_with?(scope, ":read") do %>
                    <label class="flex items-start gap-3 cursor-pointer">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-sm checkbox-primary mt-0.5"
                        checked={MapSet.member?(@selected_scopes, scope)}
                        phx-click="toggle_scope"
                        phx-value-scope={scope}
                      />
                      <div>
                        <div class="font-medium text-sm">{scope}</div>
                        <div class="text-xs text-base-content/60">{description}</div>
                      </div>
                    </label>
                  <% end %>
                </div>

                <div class="space-y-3">
                  <h3 class="font-medium text-sm text-base-content/70">Write Permissions</h3>
                  <%= for {scope, description} <- @available_scopes, String.ends_with?(scope, ":write") do %>
                    <label class="flex items-start gap-3 cursor-pointer">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-sm checkbox-primary mt-0.5"
                        checked={MapSet.member?(@selected_scopes, scope)}
                        phx-click="toggle_scope"
                        phx-value-scope={scope}
                      />
                      <div>
                        <div class="font-medium text-sm">{scope}</div>
                        <div class="text-xs text-base-content/60">{description}</div>
                      </div>
                    </label>
                  <% end %>
                </div>
              </div>

              <div :if={MapSet.size(@selected_scopes) == 0} class="alert alert-info mt-4">
                <.icon name="hero-information-circle" class="size-5" />
                <span>No scopes selected means all operations are allowed based on key type.</span>
              </div>

              <div :if={MapSet.size(@selected_scopes) > 0} class="mt-4 p-3 bg-base-300 rounded-lg">
                <div class="text-sm font-medium mb-2">Selected Scopes:</div>
                <div class="flex flex-wrap gap-2">
                  <%= for scope <- Enum.sort(MapSet.to_list(@selected_scopes)) do %>
                    <span class="badge badge-primary badge-sm">{scope}</span>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <div class="mt-6 flex gap-4">
            <.button type="submit" variant="primary" phx-disable-with="Saving...">
              Save Changes
            </.button>
            <.link
              navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys/#{@api_key.id}"}
              class="btn btn-ghost"
            >
              Cancel
            </.link>
          </div>
        </.form>
      </div>
    </FFWeb.Layouts.dashboard>
    """
  end
end
