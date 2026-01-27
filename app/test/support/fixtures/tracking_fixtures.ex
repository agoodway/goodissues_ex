defmodule FF.TrackingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `FF.Tracking` context.
  """

  alias FF.Tracking

  def unique_project_name, do: "project#{System.unique_integer()}"

  def valid_project_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_project_name(),
      description: "A test project description"
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
end
