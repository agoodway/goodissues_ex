defmodule GI.Tracking.ProjectTest do
  use GI.DataCase

  alias GI.Tracking.Project

  describe "create_changeset/2" do
    test "valid attributes" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{
          name: "My Project",
          description: "A description",
          prefix: "MP"
        })

      assert changeset.valid?
      assert get_change(changeset, :prefix) == "MP"
    end

    test "requires name" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{prefix: "MP"})

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires prefix" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{name: "My Project"})

      refute changeset.valid?
      assert %{prefix: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires account_id" do
      changeset =
        Project.create_changeset(%Project{}, %{
          name: "My Project",
          prefix: "MP"
        })

      refute changeset.valid?
      assert %{account_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates name max length" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{
          name: String.duplicate("a", 256),
          prefix: "MP"
        })

      refute changeset.valid?
      assert %{name: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "description is optional" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{
          name: "My Project",
          prefix: "MP"
        })

      assert changeset.valid?
      assert get_change(changeset, :description) == nil
    end

    test "trims name whitespace" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{
          name: "  My Project  ",
          prefix: "MP"
        })

      assert changeset.valid?
      assert get_change(changeset, :name) == "My Project"
    end

    test "normalizes prefix to uppercase" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{
          name: "My Project",
          prefix: "mp"
        })

      assert changeset.valid?
      assert get_change(changeset, :prefix) == "MP"
    end

    test "validates prefix format" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{
          name: "My Project",
          prefix: "M-P"
        })

      refute changeset.valid?
      assert %{prefix: ["must be uppercase letters and numbers only"]} = errors_on(changeset)
    end

    test "validates prefix max length" do
      changeset =
        Project.create_changeset(%Project{account_id: Ecto.UUID.generate()}, %{
          name: "My Project",
          prefix: "TOOLONGPREFIX"
        })

      refute changeset.valid?
      assert %{prefix: ["should be at most 10 character(s)"]} = errors_on(changeset)
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
