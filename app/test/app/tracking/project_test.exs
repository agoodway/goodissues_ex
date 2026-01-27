defmodule FF.Tracking.ProjectTest do
  use FF.DataCase

  alias FF.Tracking.Project

  describe "create_changeset/2" do
    test "valid attributes" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{
          name: "My Project",
          description: "A description"
        })

      assert changeset.valid?
    end

    test "requires name" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{})

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires account_id" do
      changeset =
        Project.create_changeset(%Project{}, %{
          name: "My Project"
        })

      refute changeset.valid?
      assert %{account_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates name max length" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{
          name: String.duplicate("a", 256)
        })

      refute changeset.valid?
      assert %{name: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "description is optional" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{
          name: "My Project"
        })

      assert changeset.valid?
      assert get_change(changeset, :description) == nil
    end

    test "trims name whitespace" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{
          name: "  My Project  "
        })

      assert changeset.valid?
      assert get_change(changeset, :name) == "My Project"
    end
  end

  describe "update_changeset/2" do
    test "allows partial updates" do
      project = %Project{
        id: Ecto.UUID.generate(),
        name: "Original",
        account_id: Ecto.UUID.generate()
      }

      changeset = Project.update_changeset(project, %{description: "New description"})

      assert changeset.valid?
      assert get_change(changeset, :description) == "New description"
      assert get_change(changeset, :name) == nil
    end

    test "validates name max length" do
      project = %Project{
        id: Ecto.UUID.generate(),
        name: "Original",
        account_id: Ecto.UUID.generate()
      }

      changeset = Project.update_changeset(project, %{name: String.duplicate("a", 256)})

      refute changeset.valid?
      assert %{name: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "does not allow changing account_id" do
      project = %Project{
        id: Ecto.UUID.generate(),
        name: "Original",
        account_id: Ecto.UUID.generate()
      }

      new_account_id = Ecto.UUID.generate()
      changeset = Project.update_changeset(project, %{account_id: new_account_id})

      assert get_change(changeset, :account_id) == nil
    end
  end
end
