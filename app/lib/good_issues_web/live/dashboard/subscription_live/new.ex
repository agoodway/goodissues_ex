defmodule GIWeb.Dashboard.SubscriptionLive.New do
  @moduledoc """
  Dashboard view for creating a new event subscription.
  """
  use GIWeb, :live_view

  alias GI.Accounts.Scope
  alias GI.Notifications
  alias GI.Notifications.{Event, EventSubscription}

  @impl true
  def mount(_params, _session, socket) do
    if Scope.can_manage_account?(socket.assigns.current_scope) do
      changeset = Notifications.change_subscription(%EventSubscription{})

      {:ok,
       socket
       |> assign(:page_title, "New Subscription")
       |> assign(:form, to_form(changeset))
       |> assign(:event_types, Event.event_types())
       |> assign(:selected_event_types, [])
       |> assign(:channel, "email")}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to create subscriptions.")
       |> push_navigate(
         to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/subscriptions"
       )}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"event_subscription" => params}, socket) do
    channel = params["channel"] || socket.assigns.channel
    selected = parse_event_types(params)

    changeset =
      %EventSubscription{}
      |> Notifications.change_subscription(
        build_attrs(params, socket.assigns.current_scope.account.id, selected)
      )
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:channel, channel)
     |> assign(:selected_event_types, selected)}
  end

  @impl true
  def handle_event("toggle_event_type", %{"type" => type}, socket) do
    selected = socket.assigns.selected_event_types

    updated =
      if type in selected do
        List.delete(selected, type)
      else
        [type | selected]
      end

    {:noreply, assign(socket, :selected_event_types, updated)}
  end

  @impl true
  def handle_event("save", %{"event_subscription" => params}, socket) do
    account = socket.assigns.current_scope.account
    selected = parse_event_types(params)
    attrs = build_attrs(params, account.id, selected)

    case Notifications.create_subscription(attrs) do
      {:ok, _sub} ->
        {:noreply,
         socket
         |> put_flash(:info, "Subscription created.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/subscriptions")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp build_attrs(params, account_id, selected_event_types) do
    %{
      name: params["name"],
      channel: params["channel"],
      destination: params["destination"],
      event_types: selected_event_types,
      active: true,
      account_id: account_id,
      user_id: params["user_id"]
    }
    |> Enum.reject(fn {_k, v} -> v == "" or is_nil(v) end)
    |> Map.new()
  end

  defp parse_event_types(params) do
    case params["event_types"] do
      types when is_list(types) -> types
      _ -> []
    end
  end

  defp humanize_event_type(type) do
    type
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <GIWeb.Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      active_nav={:subscriptions}
    >
      <%!-- Breadcrumb --%>
      <div class="flex items-center gap-2 mb-6 text-sm">
        <.link
          navigate={~p"/dashboard/#{@current_scope.account.slug}/subscriptions"}
          class="text-muted hover:text-base-content transition-colors flex items-center gap-1.5"
        >
          <.icon name="hero-bell" class="size-4" />
          <span>Subscriptions</span>
        </.link>
        <span class="text-muted">/</span>
        <span class="font-mono text-xs">new</span>
      </div>

      <.header>
        New Subscription
        <:subtitle>
          Subscribe to events for {@current_scope.account.name}
        </:subtitle>
      </.header>

      <div class="mt-6 max-w-xl">
        <.form
          for={@form}
          id="subscription-form"
          phx-change="validate"
          phx-submit="save"
        >
          <.input
            field={@form[:name]}
            type="text"
            label="Name"
            required
            placeholder="e.g. Slack webhook, Team alerts"
          />

          <.input
            field={@form[:channel]}
            type="select"
            label="Channel"
            options={[{"Email", "email"}, {"Webhook", "webhook"}]}
          />

          <%= if @channel == "email" do %>
            <.input
              field={@form[:destination]}
              type="email"
              label="Email Address"
              required
              placeholder="alerts@example.com"
            />
          <% else %>
            <.input
              field={@form[:destination]}
              type="url"
              label="Webhook URL"
              required
              placeholder="https://example.com/webhooks/goodissues"
            />
            <p class="text-xs text-muted mt-1 font-mono">
              // Webhooks are signed using the Standard Webhooks spec (HMAC-SHA256).
            </p>
          <% end %>

          <%!-- Event Types --%>
          <div class="mt-4">
            <label class="label">
              <span class="label-text font-semibold">Event Types</span>
            </label>
            <div class="grid grid-cols-1 gap-2 mt-2">
              <%= for type <- @event_types do %>
                <label class={[
                  "flex items-center gap-3 px-3 py-2.5 rounded-sm border cursor-pointer transition-colors",
                  to_string(type) in @selected_event_types &&
                    "border-primary/40 bg-primary/5",
                  to_string(type) not in @selected_event_types &&
                    "border-base-300/50 hover:border-base-300"
                ]}>
                  <input
                    type="checkbox"
                    name="event_subscription[event_types][]"
                    value={to_string(type)}
                    checked={to_string(type) in @selected_event_types}
                    phx-click="toggle_event_type"
                    phx-value-type={to_string(type)}
                    class="checkbox checkbox-sm checkbox-primary"
                  />
                  <div>
                    <span class="text-sm font-medium">{humanize_event_type(type)}</span>
                    <span class="text-xs text-muted font-mono ml-2">{type}</span>
                  </div>
                </label>
              <% end %>
            </div>
            <p
              :for={msg <- Enum.map(@form[:event_types].errors, &translate_error/1)}
              class="mt-1 text-sm text-error"
            >
              {msg}
            </p>
          </div>

          <div class="mt-6 flex gap-4">
            <.button type="submit" variant="primary" phx-disable-with="Creating...">
              Create Subscription
            </.button>
            <.link
              navigate={~p"/dashboard/#{@current_scope.account.slug}/subscriptions"}
              class="btn btn-ghost"
            >
              Cancel
            </.link>
          </div>
        </.form>
      </div>
    </GIWeb.Layouts.dashboard>
    """
  end
end
