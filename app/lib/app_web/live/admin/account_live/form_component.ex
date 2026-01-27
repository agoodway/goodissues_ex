defmodule FFWeb.Admin.AccountLive.FormComponent do
  use FFWeb, :live_component

  alias FF.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-bold mb-4">{@title}</h3>

      <.form
        for={@form}
        id="account-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" required />
        <.input field={@form[:slug]} type="text" label="Slug" placeholder="auto-generated from name" />
        <.input
          field={@form[:status]}
          type="select"
          label="Status"
          options={[{"Active", "active"}, {"Suspended", "suspended"}]}
        />

        <div class="modal-action">
          <.link patch={@patch} class="btn">Cancel</.link>
          <.button type="submit" variant="primary" phx-disable-with="Saving...">
            Save Account
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{account: account} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Accounts.change_account(account))
     end)}
  end

  @impl true
  def handle_event("validate", %{"account" => account_params}, socket) do
    changeset = Accounts.change_account(socket.assigns.account, account_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"account" => account_params}, socket) do
    save_account(socket, socket.assigns.action, account_params)
  end

  defp save_account(socket, :edit, account_params) do
    case Accounts.update_account(socket.assigns.account, account_params) do
      {:ok, account} ->
        notify_parent({:saved, account})

        {:noreply,
         socket
         |> put_flash(:info, "Account updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_account(socket, :new, account_params) do
    case Accounts.admin_create_account(account_params) do
      {:ok, account} ->
        notify_parent({:saved, account})

        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
