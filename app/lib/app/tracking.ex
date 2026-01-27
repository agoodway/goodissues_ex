defmodule FF.Tracking do
  @moduledoc """
  The Tracking context.
  Manages projects, issues, and related tracking functionality.
  """

  import Ecto.Query
  alias FF.Repo
  alias FF.Tracking.Project
  alias FF.Accounts.Account

  @doc """
  Lists all projects for the given account.

  ## Examples

      iex> list_projects(account)
      [%Project{}, ...]

  """
  def list_projects(%Account{id: account_id}) do
    Project
    |> where([p], p.account_id == ^account_id)
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  @doc """
  Gets a project by ID, scoped to the given account.
  Returns `nil` if the project doesn't exist or belongs to a different account.

  ## Examples

      iex> get_project(account, "valid-uuid")
      %Project{}

      iex> get_project(account, "invalid-uuid")
      nil

  """
  def get_project(%Account{id: account_id}, id) do
    Repo.get_by(Project, id: id, account_id: account_id)
  end

  @doc """
  Creates a project within the given account.

  ## Examples

      iex> create_project(account, %{name: "My Project"})
      {:ok, %Project{}}

      iex> create_project(account, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(%Account{id: account_id}, attrs) do
    %Project{account_id: account_id}
    |> Project.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project.

  ## Examples

      iex> update_project(project, %{name: "New Name"})
      {:ok, %Project{}}

      iex> update_project(project, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project.

  ## Examples

      iex> delete_project(project)
      {:ok, %Project{}}

  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end
end
