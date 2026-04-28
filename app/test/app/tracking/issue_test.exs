defmodule FF.Tracking.IssueTest do
  use FF.DataCase

  alias FF.Tracking.Issue

  describe "create_changeset/2" do
    test "valid attributes" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{
            title: "Bug report",
            description: "Something is broken",
            type: :bug,
            status: :new,
            priority: :high
          }
        )

      assert changeset.valid?
    end

    test "accepts incident type" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{title: "Incident report", type: :incident}
        )

      assert changeset.valid?
    end

    test "requires title" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{type: :bug}
        )

      refute changeset.valid?
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires type" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{title: "Test"}
        )

      refute changeset.valid?
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires project_id" do
      changeset =
        Issue.create_changeset(
          %Issue{submitter_id: Ecto.UUID.generate()},
          %{title: "Test", type: :bug}
        )

      refute changeset.valid?
      assert %{project_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires submitter_id" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate()},
          %{title: "Test", type: :bug}
        )

      refute changeset.valid?
      assert %{submitter_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates title max length" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{title: String.duplicate("a", 256), type: :bug}
        )

      refute changeset.valid?
      assert %{title: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "validates type enum" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{title: "Test", type: :invalid}
        )

      refute changeset.valid?
      assert %{type: ["is invalid"]} = errors_on(changeset)
    end

    test "validates status enum" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{title: "Test", type: :bug, status: :invalid}
        )

      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "validates priority enum" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{title: "Test", type: :bug, priority: :invalid}
        )

      refute changeset.valid?
      assert %{priority: ["is invalid"]} = errors_on(changeset)
    end

    test "description is optional" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{title: "Test", type: :bug}
        )

      assert changeset.valid?
      assert get_change(changeset, :description) == nil
    end

    test "trims title whitespace" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{title: "  Bug report  ", type: :bug}
        )

      assert changeset.valid?
      assert get_change(changeset, :title) == "Bug report"
    end

    test "sets archived_at when status is archived" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{title: "Test", type: :bug, status: :archived}
        )

      assert changeset.valid?
      assert get_change(changeset, :archived_at) != nil
    end

    test "does not set archived_at when status is not archived" do
      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{title: "Test", type: :bug, status: :new}
        )

      assert changeset.valid?
      assert get_change(changeset, :archived_at) == nil
    end

    test "validates submitter_email max length" do
      # Generate a valid email format that exceeds 255 chars
      long_email = String.duplicate("a", 244) <> "@example.com"

      changeset =
        Issue.create_changeset(
          %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()},
          %{title: "Test", type: :bug, submitter_email: long_email}
        )

      refute changeset.valid?
      assert %{submitter_email: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "defaults status to :new" do
      issue = %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()}
      assert issue.status == :new
    end

    test "defaults priority to :medium" do
      issue = %Issue{project_id: Ecto.UUID.generate(), submitter_id: Ecto.UUID.generate()}
      assert issue.priority == :medium
    end
  end

  describe "update_changeset/2" do
    test "allows partial updates" do
      issue = %Issue{
        id: Ecto.UUID.generate(),
        title: "Original",
        type: :bug,
        status: :new,
        priority: :medium,
        project_id: Ecto.UUID.generate(),
        submitter_id: Ecto.UUID.generate()
      }

      changeset = Issue.update_changeset(issue, %{description: "New description"})

      assert changeset.valid?
      assert get_change(changeset, :description) == "New description"
      assert get_change(changeset, :title) == nil
    end

    test "validates title max length" do
      issue = %Issue{
        id: Ecto.UUID.generate(),
        title: "Original",
        type: :bug,
        project_id: Ecto.UUID.generate(),
        submitter_id: Ecto.UUID.generate()
      }

      changeset = Issue.update_changeset(issue, %{title: String.duplicate("a", 256)})

      refute changeset.valid?
      assert %{title: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "does not allow changing project_id" do
      issue = %Issue{
        id: Ecto.UUID.generate(),
        title: "Original",
        type: :bug,
        project_id: Ecto.UUID.generate(),
        submitter_id: Ecto.UUID.generate()
      }

      new_project_id = Ecto.UUID.generate()
      changeset = Issue.update_changeset(issue, %{project_id: new_project_id})

      assert get_change(changeset, :project_id) == nil
    end

    test "sets archived_at when status changes to archived" do
      issue = %Issue{
        id: Ecto.UUID.generate(),
        title: "Original",
        type: :bug,
        status: :new,
        project_id: Ecto.UUID.generate(),
        submitter_id: Ecto.UUID.generate(),
        archived_at: nil
      }

      changeset = Issue.update_changeset(issue, %{status: :archived})

      assert changeset.valid?
      assert get_change(changeset, :archived_at) != nil
    end

    test "clears archived_at when status changes from archived" do
      now = DateTime.utc_now(:second)

      issue = %Issue{
        id: Ecto.UUID.generate(),
        title: "Original",
        type: :bug,
        status: :archived,
        project_id: Ecto.UUID.generate(),
        submitter_id: Ecto.UUID.generate(),
        archived_at: now
      }

      changeset = Issue.update_changeset(issue, %{status: :in_progress})

      assert changeset.valid?
      assert get_change(changeset, :archived_at) == nil
    end

    test "can update type" do
      issue = %Issue{
        id: Ecto.UUID.generate(),
        title: "Original",
        type: :bug,
        project_id: Ecto.UUID.generate(),
        submitter_id: Ecto.UUID.generate()
      }

      changeset = Issue.update_changeset(issue, %{type: :feature_request})

      assert changeset.valid?
      assert get_change(changeset, :type) == :feature_request
    end

    test "can update type to incident" do
      issue = %Issue{
        id: Ecto.UUID.generate(),
        title: "Original",
        type: :bug,
        project_id: Ecto.UUID.generate(),
        submitter_id: Ecto.UUID.generate()
      }

      changeset = Issue.update_changeset(issue, %{type: :incident})

      assert changeset.valid?
      assert get_change(changeset, :type) == :incident
    end

    test "can update priority" do
      issue = %Issue{
        id: Ecto.UUID.generate(),
        title: "Original",
        type: :bug,
        priority: :low,
        project_id: Ecto.UUID.generate(),
        submitter_id: Ecto.UUID.generate()
      }

      changeset = Issue.update_changeset(issue, %{priority: :critical})

      assert changeset.valid?
      assert get_change(changeset, :priority) == :critical
    end
  end
end
