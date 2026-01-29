defmodule FF.TrackingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FF.Tracking` context.
  """

  alias FF.Tracking

  def unique_project_name, do: "project#{System.unique_integer()}"
  def unique_issue_title, do: "issue#{System.unique_integer()}"
  def unique_project_prefix, do: "P#{:erlang.unique_integer([:positive]) |> rem(9999)}"

  def valid_project_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_project_name(),
      description: "A test project description",
      prefix: unique_project_prefix()
    })
  end

  @doc """
  Creates a project fixture.

  Requires an account to be passed in attrs.
  """
  def project_fixture(account, attrs \\ %{}) do
    {:ok, project} =
      attrs
      |> valid_project_attributes()
      |> then(&Tracking.create_project(account, &1))

    project
  end

  def valid_issue_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: unique_issue_title(),
      description: "A test issue description",
      type: :bug,
      status: :new,
      priority: :medium
    })
  end

  @doc """
  Creates an issue fixture.

  Requires an account, user, and project to be passed.
  """
  def issue_fixture(account, user, project, attrs \\ %{}) do
    {:ok, issue} =
      attrs
      |> valid_issue_attributes()
      |> Map.put(:project_id, project.id)
      |> then(&Tracking.create_issue(account, user, &1))

    issue
  end
end
