defmodule FF.Tracking do
  @moduledoc """
  The Tracking context.
  Manages projects, issues, and related tracking functionality.
  """

  import Ecto.Query
  alias FF.Repo
  alias FF.Tracking.{Issue, Project}
  alias FF.Accounts.{Account, User}

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

  # ==========================================================================
  # Issues
  # ==========================================================================

  @default_per_page 20
  @max_per_page 100

  @doc """
  Lists issues for the given account with optional filters and pagination.

  ## Options

    * `:project_id` - Filter by project ID
    * `:status` - Filter by status (new, in_progress, archived)
    * `:type` - Filter by type (bug, feature_request)
    * `:page` - Page number (default: 1)
    * `:per_page` - Results per page (default: #{@default_per_page}, max: #{@max_per_page})

  ## Examples

      iex> list_issues(account, %{})
      [%Issue{}, ...]

      iex> list_issues(account, %{status: :new, project_id: "...", page: 2, per_page: 10})
      [%Issue{}, ...]

  """
  def list_issues(%Account{id: account_id}, filters \\ %{}) do
    {page, per_page} = extract_pagination(filters)

    Issue
    |> join(:inner, [i], p in Project, on: i.project_id == p.id)
    |> where([i, p], p.account_id == ^account_id)
    |> apply_issue_filters(filters)
    |> order_by([i], desc: i.inserted_at)
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> Repo.all()
  end

  @doc """
  Lists issues for the given account with pagination metadata.

  Returns a map with:
    * `:issues` - List of issues with preloaded project
    * `:page` - Current page number
    * `:per_page` - Results per page
    * `:total` - Total count of matching issues
    * `:total_pages` - Total number of pages

  ## Options

    * `:project_id` - Filter by project ID
    * `:status` - Filter by status (new, in_progress, archived)
    * `:type` - Filter by type (bug, feature_request)
    * `:page` - Page number (default: 1)
    * `:per_page` - Results per page (default: #{@default_per_page}, max: #{@max_per_page})

  """
  def list_issues_paginated(%Account{id: account_id}, filters \\ %{}) do
    {page, per_page} = extract_pagination(filters)

    base_query =
      Issue
      |> join(:inner, [i], p in Project, on: i.project_id == p.id)
      |> where([i, p], p.account_id == ^account_id)
      |> apply_issue_filters(filters)

    total = Repo.aggregate(base_query, :count)
    total_pages = max(ceil(total / per_page), 1)

    issues =
      base_query
      |> order_by([i], desc: i.inserted_at)
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> preload(:project)
      |> Repo.all()

    %{
      issues: issues,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: total_pages
    }
  end

  defp extract_pagination(filters) do
    page = parse_positive_int(filters[:page] || filters["page"], 1)
    per_page = parse_positive_int(filters[:per_page] || filters["per_page"], @default_per_page)
    {page, min(per_page, @max_per_page)}
  end

  defp parse_positive_int(value, _default) when is_integer(value) and value > 0, do: value

  defp parse_positive_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _ -> default
    end
  end

  defp parse_positive_int(_, default), do: default

  @valid_statuses ~w(new in_progress archived)
  @valid_types ~w(bug feature_request)

  defp apply_issue_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:project_id, project_id}, query when is_binary(project_id) ->
        if valid_uuid?(project_id) do
          where(query, [i], i.project_id == ^project_id)
        else
          query
        end

      {:status, status}, query when status in [:new, :in_progress, :archived] ->
        where(query, [i], i.status == ^status)

      {:status, status}, query when is_binary(status) ->
        if status in @valid_statuses do
          where(query, [i], i.status == ^status)
        else
          query
        end

      {:type, type}, query when type in [:bug, :feature_request] ->
        where(query, [i], i.type == ^type)

      {:type, type}, query when is_binary(type) ->
        if type in @valid_types do
          where(query, [i], i.type == ^type)
        else
          query
        end

      _, query ->
        query
    end)
  end

  defp valid_uuid?(string) when is_binary(string) do
    case Ecto.UUID.dump(string) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp valid_uuid?(_), do: false

  @doc """
  Gets an issue by ID, scoped to the given account.
  Returns `nil` if the issue doesn't exist or belongs to a different account.

  ## Examples

      iex> get_issue(account, "valid-uuid")
      %Issue{}

      iex> get_issue(account, "invalid-uuid")
      nil

  """
  def get_issue(%Account{id: account_id}, id) do
    if valid_uuid?(id) do
      Issue
      |> join(:inner, [i], p in Project, on: i.project_id == p.id)
      |> where([i, p], i.id == ^id and p.account_id == ^account_id)
      |> Repo.one()
    else
      nil
    end
  end

  @doc """
  Creates an issue within a project.

  ## Examples

      iex> create_issue(account, user, %{title: "Bug", type: :bug, project_id: "..."})
      {:ok, %Issue{}}

      iex> create_issue(account, user, %{})
      {:error, %Ecto.Changeset{}}

  """
  def create_issue(%Account{} = account, %User{id: user_id}, attrs) do
    project_id = attrs[:project_id] || attrs["project_id"]

    # Verify project belongs to account
    case get_project(account, project_id) do
      nil ->
        changeset =
          %Issue{}
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.add_error(:project_id, "does not exist or belongs to another account")

        {:error, changeset}

      _project ->
        %Issue{project_id: project_id, submitter_id: user_id}
        |> Issue.create_changeset(attrs)
        |> Repo.insert()
    end
  end

  @doc """
  Updates an issue.

  ## Examples

      iex> update_issue(issue, %{title: "New Title"})
      {:ok, %Issue{}}

      iex> update_issue(issue, %{title: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_issue(%Issue{} = issue, attrs) do
    issue
    |> Issue.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an issue.

  ## Examples

      iex> delete_issue(issue)
      {:ok, %Issue{}}

  """
  def delete_issue(%Issue{} = issue) do
    Repo.delete(issue)
  end
end
