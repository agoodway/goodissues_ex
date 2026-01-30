defmodule FF.Tracking do
  @moduledoc """
  The Tracking context.
  Manages projects, issues, and related tracking functionality.

  ## PubSub Events

  This module broadcasts events when issues are created or updated:

  - `:issue_created` - Broadcast to `"issues:account:<account_id>"` when an issue is created
  - `:issue_updated` - Broadcast to `"issues:account:<account_id>"` when an issue is updated

  Subscribe to these events in LiveViews to receive realtime updates.
  """

  import Ecto.Query

  alias FF.Accounts.{Account, User}
  alias FF.Repo
  alias FF.Tracking.{Error, Issue, Occurrence, Project, StacktraceLine}

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
    if valid_uuid?(id) do
      Repo.get_by(Project, id: id, account_id: account_id)
    else
      nil
    end
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

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes (for updates).
  """
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.update_changeset(project, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for creating a new project.
  """
  def change_new_project(%Project{} = project, attrs \\ %{}) do
    Project.create_changeset(project, attrs)
  end

  @doc """
  Returns a suggested prefix for a project name.
  """
  defdelegate suggest_prefix(name), to: Project

  @doc """
  Counts issues for a given project.
  """
  def count_issues(%Project{id: project_id}) do
    Issue
    |> where([i], i.project_id == ^project_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Lists projects with issue counts for an account.
  Returns a list of {project, issue_count} tuples.
  """
  def list_projects_with_counts(%Account{id: account_id}) do
    Project
    |> where([p], p.account_id == ^account_id)
    |> join(:left, [p], i in Issue, on: i.project_id == p.id)
    |> group_by([p], p.id)
    |> select([p, i], {p, count(i.id)})
    |> order_by([p], asc: p.name)
    |> Repo.all()
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

  ## Options

    * `:preload` - List of associations to preload (e.g., `[:project, :submitter]`)
    * `:preload_error_with_count` - When true, preloads error with occurrence count
      and latest occurrence's stacktrace lines

  ## Examples

      iex> get_issue(account, "valid-uuid")
      %Issue{}

      iex> get_issue(account, "invalid-uuid")
      nil

      iex> get_issue(account, "valid-uuid", preload: [:project, :submitter])
      %Issue{project: %Project{}, submitter: %User{}}

      iex> get_issue(account, "valid-uuid", preload_error_with_count: true)
      %Issue{error: %Error{occurrence_count: 5, ...}}

  """
  def get_issue(%Account{id: account_id}, id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])
    preload_error_with_count = Keyword.get(opts, :preload_error_with_count, false)

    if valid_uuid?(id) do
      issue =
        Issue
        |> join(:inner, [i], p in Project, on: i.project_id == p.id)
        |> where([i, p], i.id == ^id and p.account_id == ^account_id)
        |> preload(^preloads)
        |> Repo.one()

      if issue && preload_error_with_count do
        preload_error_with_occurrence_count(issue)
      else
        issue
      end
    else
      nil
    end
  end

  defp preload_error_with_occurrence_count(nil), do: nil

  defp preload_error_with_occurrence_count(%Issue{} = issue) do
    case get_error_for_issue(issue.id) do
      nil ->
        %{issue | error: nil}

      error ->
        %{issue | error: error}
    end
  end

  defp get_error_for_issue(issue_id) do
    Error
    |> where([e], e.issue_id == ^issue_id)
    |> join(:left, [e], o in Occurrence, on: o.error_id == e.id)
    |> group_by([e], e.id)
    |> select([e, o], %{e | occurrence_count: count(o.id)})
    |> Repo.one()
    |> case do
      nil ->
        nil

      error ->
        # Preload the latest occurrence with stacktrace
        error
        |> Repo.preload(occurrences: from(o in Occurrence, order_by: [desc: o.inserted_at], limit: 1, preload: :stacktrace_lines))
    end
  end

  @doc """
  Creates an issue within a project.

  The issue number is assigned atomically from the project's issue_counter.
  Uses a database lock to prevent race conditions.

  ## Examples

      iex> create_issue(account, user, %{title: "Bug", type: :bug, project_id: "..."})
      {:ok, %Issue{}}

      iex> create_issue(account, user, %{})
      {:error, %Ecto.Changeset{}}

  """
  def create_issue(%Account{} = account, %User{id: user_id}, attrs) do
    project_id = attrs[:project_id] || attrs["project_id"]

    result =
      Repo.transaction(fn ->
        project = lock_project_for_issue(project_id, account.id)
        create_issue_with_number(project, project_id, user_id, attrs)
      end)

    case result do
      {:ok, issue} ->
        broadcast_issue_created(account.id, issue)
        {:ok, issue}

      {:error, _} = error ->
        error
    end
  end

  defp lock_project_for_issue(project_id, account_id) do
    Project
    |> where([p], p.id == ^project_id and p.account_id == ^account_id)
    |> lock("FOR UPDATE")
    |> Repo.one()
  end

  defp create_issue_with_number(nil, _project_id, _user_id, _attrs) do
    changeset =
      %Issue{}
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.add_error(:project_id, "does not exist or belongs to another account")

    Repo.rollback(changeset)
  end

  defp create_issue_with_number(project, project_id, user_id, attrs) do
    number = project.issue_counter

    project
    |> Project.increment_counter_changeset()
    |> Repo.update!()

    case %Issue{project_id: project_id, submitter_id: user_id, number: number}
         |> Issue.create_changeset(attrs)
         |> Repo.insert() do
      {:ok, issue} -> Repo.preload(issue, :project)
      {:error, changeset} -> Repo.rollback(changeset)
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
    result =
      issue
      |> Issue.update_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_issue} ->
        # Need to get account_id from the project
        updated_issue = Repo.preload(updated_issue, :project)
        broadcast_issue_updated(updated_issue.project.account_id, updated_issue)
        {:ok, updated_issue}

      {:error, _} = error ->
        error
    end
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

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking issue changes (for updates).

  ## Examples

      iex> change_issue(issue)
      %Ecto.Changeset{data: %Issue{}}

  """
  def change_issue(%Issue{} = issue, attrs \\ %{}) do
    Issue.update_changeset(issue, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for creating a new issue.

  ## Examples

      iex> change_new_issue(issue, attrs)
      %Ecto.Changeset{data: %Issue{}}

  """
  def change_new_issue(%Issue{} = issue, attrs \\ %{}) do
    Issue.create_changeset(issue, attrs)
  end

  # ==========================================================================
  # PubSub Broadcasting
  # ==========================================================================

  @doc """
  Returns the PubSub topic for issue events for a given account.

  ## Examples

      iex> issues_topic("account-uuid")
      "issues:account:account-uuid"

  """
  def issues_topic(account_id) when is_binary(account_id) do
    "issues:account:#{account_id}"
  end

  defp broadcast_issue_created(account_id, %Issue{} = issue) do
    Phoenix.PubSub.broadcast(
      FF.PubSub,
      issues_topic(account_id),
      {:issue_created, issue_payload(issue)}
    )
  end

  defp broadcast_issue_updated(account_id, %Issue{} = issue) do
    Phoenix.PubSub.broadcast(
      FF.PubSub,
      issues_topic(account_id),
      {:issue_updated, issue_payload(issue)}
    )
  end

  defp issue_payload(%Issue{} = issue) do
    %{
      id: issue.id,
      project_id: issue.project_id,
      title: issue.title,
      status: issue.status,
      type: issue.type,
      priority: issue.priority,
      number: issue.number,
      inserted_at: issue.inserted_at,
      updated_at: issue.updated_at,
      project: %{
        id: issue.project.id,
        prefix: issue.project.prefix
      }
    }
  end

  # ==========================================================================
  # Errors
  # ==========================================================================

  @doc """
  Gets an error by fingerprint within an account.
  Returns nil if not found.

  ## Examples

      iex> get_error_by_fingerprint(account, "abc123...")
      %Error{}

      iex> get_error_by_fingerprint(account, "nonexistent")
      nil

  """
  def get_error_by_fingerprint(%Account{id: account_id}, fingerprint) do
    Error
    |> join(:inner, [e], i in Issue, on: e.issue_id == i.id)
    |> join(:inner, [e, i], p in Project, on: i.project_id == p.id)
    |> where([e, i, p], e.fingerprint == ^fingerprint and p.account_id == ^account_id)
    |> preload(:issue)
    |> Repo.one()
  end

  @doc """
  Gets an error summary with occurrence count.

  Returns the error with a virtual `:occurrence_count` field populated,
  or nil if the error doesn't exist.

  ## Examples

      iex> get_error_summary(error_id)
      %Error{occurrence_count: 5, ...}

      iex> get_error_summary("nonexistent")
      nil

  """
  def get_error_summary(error_id) when is_binary(error_id) do
    if valid_uuid?(error_id) do
      Error
      |> where([e], e.id == ^error_id)
      |> join(:left, [e], o in Occurrence, on: o.error_id == e.id)
      |> group_by([e], e.id)
      |> select([e, o], %{e | occurrence_count: count(o.id)})
      |> preload([e], [:issue, occurrences: :stacktrace_lines])
      |> Repo.one()
    else
      nil
    end
  end

  def get_error_summary(nil), do: nil

  @doc """
  Gets an error by ID, scoped to the given account.
  Returns nil if not found or belongs to a different account.

  ## Options

    * `:preload` - List of associations to preload

  ## Examples

      iex> get_error(account, "valid-uuid")
      %Error{}

      iex> get_error(account, "invalid-uuid")
      nil

  """
  def get_error(%Account{id: account_id}, id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    if valid_uuid?(id) do
      Error
      |> join(:inner, [e], i in Issue, on: e.issue_id == i.id)
      |> join(:inner, [e, i], p in Project, on: i.project_id == p.id)
      |> where([e, i, p], e.id == ^id and p.account_id == ^account_id)
      |> preload(^preloads)
      |> Repo.one()
    else
      nil
    end
  end

  @doc """
  Lists errors for the given account with optional filters and pagination.

  ## Options

    * `:status` - Filter by status (resolved, unresolved)
    * `:muted` - Filter by muted status (true, false)
    * `:page` - Page number (default: 1)
    * `:per_page` - Results per page (default: 20, max: 100)

  ## Examples

      iex> list_errors(account)
      [%Error{}, ...]

      iex> list_errors(account, %{status: :unresolved})
      [%Error{}, ...]

  """
  def list_errors(%Account{id: account_id}, filters \\ %{}) do
    {page, per_page} = extract_pagination(filters)

    Error
    |> join(:inner, [e], i in Issue, on: e.issue_id == i.id)
    |> join(:inner, [e, i], p in Project, on: i.project_id == p.id)
    |> where([e, i, p], p.account_id == ^account_id)
    |> apply_error_filters(filters)
    |> order_by([e], desc: e.last_occurrence_at)
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> preload(:issue)
    |> Repo.all()
  end

  @doc """
  Lists errors for the given account with pagination metadata.

  Returns a map with:
    * `:errors` - List of errors with preloaded issue
    * `:page` - Current page number
    * `:per_page` - Results per page
    * `:total` - Total count of matching errors
    * `:total_pages` - Total number of pages

  """
  def list_errors_paginated(%Account{id: account_id}, filters \\ %{}) do
    {page, per_page} = extract_pagination(filters)

    base_query =
      Error
      |> join(:inner, [e], i in Issue, on: e.issue_id == i.id)
      |> join(:inner, [e, i], p in Project, on: i.project_id == p.id)
      |> where([e, i, p], p.account_id == ^account_id)
      |> apply_error_filters(filters)

    total = Repo.aggregate(base_query, :count)
    total_pages = max(ceil(total / per_page), 1)

    errors =
      base_query
      |> order_by([e], desc: e.last_occurrence_at)
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> preload(:issue)
      |> Repo.all()

    %{
      errors: errors,
      page: page,
      per_page: per_page,
      total: total,
      total_pages: total_pages
    }
  end

  @valid_error_statuses ~w(resolved unresolved)

  defp apply_error_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:status, status}, query when status in [:resolved, :unresolved] ->
        where(query, [e], e.status == ^status)

      {:status, status}, query when is_binary(status) ->
        if status in @valid_error_statuses do
          where(query, [e], e.status == ^status)
        else
          query
        end

      {:muted, muted}, query when is_boolean(muted) ->
        where(query, [e], e.muted == ^muted)

      _, query ->
        query
    end)
  end

  @doc """
  Creates an error with its first occurrence and stacktrace lines.

  ## Examples

      iex> create_error_with_occurrence(issue, error_attrs, occurrence_attrs)
      {:ok, %Error{}}

      iex> create_error_with_occurrence(issue, invalid_attrs, occurrence_attrs)
      {:error, %Ecto.Changeset{}}

  """
  def create_error_with_occurrence(%Issue{id: issue_id}, error_attrs, occurrence_attrs) do
    Repo.transaction(fn ->
      with {:ok, error} <- insert_error(issue_id, error_attrs),
           {:ok, _occurrence} <- create_occurrence_with_stacktrace(error, occurrence_attrs) do
        Repo.preload(error, [:issue, occurrences: :stacktrace_lines])
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp insert_error(issue_id, error_attrs) do
    %Error{issue_id: issue_id}
    |> Error.create_changeset(error_attrs)
    |> Repo.insert()
  end

  @doc """
  Adds an occurrence to an existing error, updating last_occurrence_at.

  ## Examples

      iex> add_occurrence(error, occurrence_attrs)
      {:ok, %Occurrence{}}

  """
  def add_occurrence(%Error{} = error, occurrence_attrs) do
    Repo.transaction(fn ->
      # Create occurrence with stacktrace
      case create_occurrence_with_stacktrace(error, occurrence_attrs) do
        {:ok, occurrence} ->
          # Update error's last_occurrence_at
          {:ok, _error} =
            error
            |> Error.update_changeset(%{last_occurrence_at: DateTime.utc_now(:second)})
            |> Repo.update()

          occurrence

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  defp create_occurrence_with_stacktrace(%Error{id: error_id}, attrs) do
    stacktrace_lines = attrs[:stacktrace_lines] || attrs["stacktrace_lines"] || []

    case %Occurrence{error_id: error_id}
         |> Occurrence.create_changeset(attrs)
         |> Repo.insert() do
      {:ok, occurrence} ->
        # Bulk insert stacktrace lines
        lines_to_insert =
          stacktrace_lines
          |> Enum.with_index()
          |> Enum.map(fn {line_attrs, position} ->
            line_attrs = atomize_keys(line_attrs)

            %{
              id: Ecto.UUID.generate(),
              occurrence_id: occurrence.id,
              position: position,
              application: line_attrs[:application],
              module: line_attrs[:module],
              function: line_attrs[:function],
              arity: line_attrs[:arity],
              file: line_attrs[:file],
              line: line_attrs[:line]
            }
          end)

        if lines_to_insert != [] do
          Repo.insert_all(StacktraceLine, lines_to_insert)
        end

        {:ok, Repo.preload(occurrence, :stacktrace_lines)}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} when is_atom(k) -> {k, v}
    end)
  rescue
    ArgumentError -> map
  end

  defp atomize_keys(other), do: other

  @doc """
  Reports an error with fingerprint deduplication.

  If an error with the same fingerprint exists in the account, adds a new occurrence.
  Otherwise, creates a new issue and error.

  Uses advisory locking to prevent race conditions with concurrent requests.

  Returns `{:ok, error, :created}` for new errors or `{:ok, error, :occurrence_added}` for existing.

  ## Examples

      iex> report_error(account, user, project_id, error_attrs, occurrence_attrs)
      {:ok, %Error{}, :created}

  """
  def report_error(
        %Account{} = account,
        %User{} = user,
        project_id,
        error_attrs,
        occurrence_attrs
      ) do
    fingerprint = error_attrs[:fingerprint] || error_attrs["fingerprint"]

    case get_project(account, project_id) do
      nil ->
        {:error, :project_not_found}

      _project ->
        report_error_with_lock(
          account,
          user,
          project_id,
          fingerprint,
          error_attrs,
          occurrence_attrs
        )
    end
  end

  defp report_error_with_lock(
         account,
         user,
         project_id,
         fingerprint,
         error_attrs,
         occurrence_attrs
       ) do
    lock_key = fingerprint_lock_key(account.id, fingerprint)

    result =
      Repo.transaction(fn ->
        Repo.query!("SELECT pg_advisory_xact_lock($1)", [lock_key])

        execute_report_error(
          account,
          user,
          project_id,
          fingerprint,
          error_attrs,
          occurrence_attrs
        )
      end)

    case result do
      {:ok, {error, status}} -> {:ok, error, status}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp execute_report_error(account, user, project_id, fingerprint, error_attrs, occurrence_attrs) do
    case do_report_error(account, user, project_id, fingerprint, error_attrs, occurrence_attrs) do
      {:ok, error, status} -> {error, status}
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end

  # Generate a consistent lock key from account_id and fingerprint
  defp fingerprint_lock_key(account_id, fingerprint) do
    :erlang.phash2({account_id, fingerprint})
  end

  defp do_report_error(account, user, project_id, fingerprint, error_attrs, occurrence_attrs) do
    case get_error_by_fingerprint(account, fingerprint) do
      nil ->
        create_new_error(account, user, project_id, error_attrs, occurrence_attrs)

      existing_error ->
        add_occurrence_to_existing(existing_error, occurrence_attrs)
    end
  end

  defp create_new_error(account, user, project_id, error_attrs, occurrence_attrs) do
    issue_attrs = %{
      title: error_attrs[:kind] || error_attrs["kind"],
      description: error_attrs[:reason] || error_attrs["reason"],
      type: :bug,
      project_id: project_id
    }

    case create_issue(account, user, issue_attrs) do
      {:ok, issue} ->
        case create_error_with_occurrence(issue, error_attrs, occurrence_attrs) do
          {:ok, error} -> {:ok, error, :created}
          {:error, _} = error -> error
        end

      {:error, _} = error ->
        error
    end
  end

  defp add_occurrence_to_existing(existing_error, occurrence_attrs) do
    case add_occurrence(existing_error, occurrence_attrs) do
      {:ok, _occurrence} ->
        {:ok, Repo.preload(existing_error, [:issue, :occurrences], force: true),
         :occurrence_added}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Updates an error.

  ## Examples

      iex> update_error(error, %{status: :resolved})
      {:ok, %Error{}}

  """
  def update_error(%Error{} = error, attrs) do
    error
    |> Error.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets an error with paginated occurrences.

  ## Options

    * `:page` - Page number for occurrences (default: 1)
    * `:per_page` - Occurrences per page (default: 20, max: 100)

  """
  def get_error_with_occurrences(%Account{} = account, error_id, opts \\ []) do
    opts_map = Enum.into(opts, %{})
    {page, per_page} = extract_pagination(opts_map)

    case get_error(account, error_id, preload: [:issue]) do
      nil ->
        nil

      error ->
        occurrences =
          Occurrence
          |> where([o], o.error_id == ^error_id)
          |> order_by([o], desc: o.inserted_at)
          |> limit(^per_page)
          |> offset(^((page - 1) * per_page))
          |> preload(:stacktrace_lines)
          |> Repo.all()

        occurrence_count =
          Occurrence
          |> where([o], o.error_id == ^error_id)
          |> Repo.aggregate(:count)

        %{error | occurrences: occurrences}
        |> Map.put(:occurrence_count, occurrence_count)
    end
  end

  @doc """
  Searches errors by stacktrace fields (module, function, file).

  ## Options

    * `:module` - Search by module name
    * `:function` - Search by function name
    * `:file` - Search by file path
    * `:page` - Page number (default: 1)
    * `:per_page` - Results per page (default: 20, max: 100)

  ## Examples

      iex> search_errors_by_stacktrace(account, %{module: "MyApp.Worker"})
      [%Error{}, ...]

  """
  def search_errors_by_stacktrace(%Account{id: account_id}, filters \\ %{}) do
    {page, per_page} = extract_pagination(filters)

    Error
    |> join(:inner, [e], i in Issue, on: e.issue_id == i.id)
    |> join(:inner, [e, i], p in Project, on: i.project_id == p.id)
    |> join(:inner, [e, i, p], o in Occurrence, on: o.error_id == e.id)
    |> join(:inner, [e, i, p, o], s in StacktraceLine, on: s.occurrence_id == o.id)
    |> where([e, i, p, o, s], p.account_id == ^account_id)
    |> apply_stacktrace_filters(filters)
    |> distinct([e], e.id)
    |> order_by([e], desc: e.last_occurrence_at)
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
    |> preload(:issue)
    |> Repo.all()
  end

  defp apply_stacktrace_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:module, module}, query when is_binary(module) and module != "" ->
        where(query, [e, i, p, o, s], s.module == ^module)

      {:function, function}, query when is_binary(function) and function != "" ->
        where(query, [e, i, p, o, s], s.function == ^function)

      {:file, file}, query when is_binary(file) and file != "" ->
        where(query, [e, i, p, o, s], s.file == ^file)

      _, query ->
        query
    end)
  end
end
