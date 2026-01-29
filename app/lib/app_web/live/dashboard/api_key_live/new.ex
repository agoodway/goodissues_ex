defmodule FFWeb.Dashboard.ApiKeyLive.New do
  @moduledoc """
  Dashboard view for creating a new API key for the current account.

  Only users with owner/admin role can create API keys.
  """
  use FFWeb, :live_view

  alias FF.Accounts
  alias FF.Accounts.ApiKey
  alias FF.Accounts.Scope

  @impl true
  def mount(_params, _session, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      {:ok,
       socket
       |> assign(:page_title, "New API Key")
       |> assign(:form, to_form(Accounts.change_api_key(%ApiKey{})))
       |> assign(:created_api_key, nil)
       |> assign(:created_token, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to create API keys.")
       |> push_navigate(to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/api-keys")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"api_key" => api_key_params}, socket) do
    changeset =
      %ApiKey{}
      |> Accounts.change_api_key(api_key_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"api_key" => api_key_params}, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      # Use the current user's account_user for the current account
      account_user = socket.assigns.current_scope.account_user

      attrs = %{
        name: api_key_params["name"],
        type: String.to_existing_atom(api_key_params["type"] || "public"),
        scopes: parse_scopes(api_key_params["scopes"]),
        expires_at: parse_expiration(api_key_params["expires_at"])
      }

      case Accounts.create_api_key(account_user, attrs) do
        {:ok, {api_key, token}} ->
          {:noreply,
           socket
           |> put_flash(:info, "API key created successfully.")
           |> assign(:created_api_key, Accounts.get_api_key!(api_key.id))
           |> assign(:created_token, token)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :form, to_form(changeset))}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You don't have permission to create API keys.")
       |> push_navigate(to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/api-keys")}
    end
  end

  defp parse_scopes(nil), do: []
  defp parse_scopes(""), do: []

  defp parse_scopes(scopes) when is_binary(scopes) do
    scopes
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_expiration(nil), do: nil
  defp parse_expiration(""), do: nil

  defp parse_expiration(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string <> "T23:59:59Z") do
      {:ok, dt, _offset} -> dt
      _ -> nil
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
        New API Key
        <:subtitle>Create a new API key for {@current_scope.account.name}</:subtitle>
      </.header>

      <%= if @created_token do %>
        <div class="mt-6">
          <div class="alert alert-warning mb-6">
            <.icon name="hero-exclamation-triangle" class="size-6" />
            <div>
              <h3 class="font-bold">Save this token now!</h3>
              <p>
                This token will only be shown once and cannot be retrieved later. Copy and store it securely.
              </p>
            </div>
          </div>

          <div class="card bg-base-200">
            <div class="card-body">
              <h2 class="card-title">API Key Created Successfully</h2>

              <div class="form-control">
                <label class="label">
                  <span class="label-text font-semibold">API Token</span>
                </label>
                <div class="flex gap-2">
                  <input
                    type="text"
                    value={@created_token}
                    readonly
                    class="input input-bordered flex-1 font-mono text-sm"
                    id="api-token"
                  />
                  <button
                    type="button"
                    class="btn btn-primary"
                    phx-hook="CopyToClipboard"
                    id="copy-token-btn"
                    data-copy-target="api-token"
                  >
                    <.icon name="hero-clipboard-document" class="size-4 mr-1" /> Copy
                  </button>
                </div>
              </div>

              <div class="mt-4">
                <.list>
                  <:item title="Name">{@created_api_key.name}</:item>
                  <:item title="Type">
                    <span class={[
                      "badge badge-sm",
                      @created_api_key.type == :private && "badge-warning",
                      @created_api_key.type == :public && "badge-info"
                    ]}>
                      {@created_api_key.type}
                    </span>
                  </:item>
                  <:item title="Owner">{@created_api_key.account_user.user.email}</:item>
                  <:item title="Account">{@created_api_key.account_user.account.name}</:item>
                </.list>
              </div>

              <div class="card-actions justify-end mt-4">
                <.link
                  navigate={
                    ~p"/dashboard/#{@current_scope.account.slug}/api-keys/#{@created_api_key.id}"
                  }
                  class="btn btn-primary"
                >
                  View API Key Details
                </.link>
                <.link
                  navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys"}
                  class="btn btn-ghost"
                >
                  Back to API Keys
                </.link>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <div class="mt-6 max-w-xl">
          <.form for={@form} id="api-key-form" phx-change="validate" phx-submit="save">
            <.input field={@form[:name]} type="text" label="Name" required />

            <div class="form-control mt-4">
              <label class="label">
                <span class="label-text">Owner</span>
              </label>
              <div class="input input-bordered flex items-center bg-base-200 text-base-content/70">
                {@current_scope.user.email} (as {@current_scope.account_user.role})
              </div>
              <label class="label">
                <span class="label-text-alt text-base-content/50">
                  API key will be created for your membership in {@current_scope.account.name}
                </span>
              </label>
            </div>

            <.input
              field={@form[:type]}
              type="select"
              label="Type"
              options={[{"Public (read-only)", "public"}, {"Private (read/write)", "private"}]}
            />

            <.input
              field={@form[:scopes]}
              type="text"
              label="Scopes (comma-separated, optional)"
              placeholder="read:projects, write:projects"
            />

            <.input field={@form[:expires_at]} type="date" label="Expires At (optional)" />

            <div class="mt-6 flex gap-4">
              <.button type="submit" variant="primary" phx-disable-with="Creating...">
                Create API Key
              </.button>
              <.link
                navigate={~p"/dashboard/#{@current_scope.account.slug}/api-keys"}
                class="btn btn-ghost"
              >
                Cancel
              </.link>
            </div>
          </.form>
        </div>
      <% end %>
    </FFWeb.Layouts.dashboard>
    """
  end
end
