defmodule FFWeb.Dashboard.IssueLive.FormComponent do
  @moduledoc """
  Reusable form component for creating and editing issues.
  """
  use FFWeb, :live_component

  alias FF.Tracking

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-bold mb-4">{@title}</h3>

      <.form
        for={@form}
        id="issue-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:title]} type="text" label="Title" required />

        <.input
          field={@form[:project_id]}
          type="select"
          label="Project"
          options={Enum.map(@projects, &{&1.name, &1.id})}
          prompt="Select a project"
          required
          disabled={@action == :edit}
        />

        <.input
          field={@form[:type]}
          type="select"
          label="Type"
          options={[{"Bug", "bug"}, {"Feature Request", "feature_request"}]}
          required
        />

        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          options={[{"New", "new"}, {"In Progress", "in_progress"}, {"Archived", "archived"}]}
        />

        <.input
          field={@form[:priority]}
          type="select"
          label="Priority"
          options={[{"Low", "low"}, {"Medium", "medium"}, {"High", "high"}, {"Critical", "critical"}]}
        />

        <.input
          field={@form[:description]}
          type="textarea"
          label="Description"
          rows={5}
        />

        <.input
          field={@form[:submitter_email]}
          type="email"
          label="Submitter Email (optional)"
          placeholder="reporter@example.com"
        />

        <div class="modal-action">
          <.link patch={@patch} class="btn">Cancel</.link>
          <.button type="submit" variant="primary" phx-disable-with="Saving...">
            {if @action == :new, do: "Create Issue", else: "Save Changes"}
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{issue: issue, action: action} = assigns, socket) do
    changeset = changeset_for_action(issue, %{}, action)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn -> to_form(changeset) end)}
  end

  @impl true
  def handle_event("validate", %{"issue" => issue_params}, socket) do
    changeset =
      socket.assigns.issue
      |> changeset_for_action(issue_params, socket.assigns.action)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"issue" => issue_params}, socket) do
    save_issue(socket, socket.assigns.action, issue_params)
  end

  defp changeset_for_action(issue, attrs, :new), do: Tracking.change_new_issue(issue, attrs)
  defp changeset_for_action(issue, attrs, :edit), do: Tracking.change_issue(issue, attrs)

  defp save_issue(socket, :edit, issue_params) do
    account = socket.assigns.current_scope.account

    # Re-fetch issue with account scope to prevent TOCTOU race condition
    case Tracking.get_issue(account, socket.assigns.issue.id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Issue not found.")
         |> push_navigate(to: ~p"/dashboard/#{account.slug}/issues")}

      issue ->
        case Tracking.update_issue(issue, issue_params) do
          {:ok, updated_issue} ->
            notify_parent({:saved, updated_issue})

            {:noreply,
             socket
             |> put_flash(:info, "Issue updated successfully.")
             |> push_patch(to: socket.assigns.patch)}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
    end
  end

  defp save_issue(socket, :new, issue_params) do
    account = socket.assigns.current_scope.account
    user = socket.assigns.current_scope.user

    case Tracking.create_issue(account, user, issue_params) do
      {:ok, issue} ->
        notify_parent({:saved, issue})

        {:noreply,
         socket
         |> put_flash(:info, "Issue created successfully.")
         |> push_navigate(
           to: ~p"/dashboard/#{socket.assigns.current_scope.account.slug}/issues/#{issue.id}"
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
