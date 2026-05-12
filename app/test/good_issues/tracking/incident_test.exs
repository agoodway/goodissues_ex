defmodule GI.Tracking.IncidentTest do
  use GI.DataCase, async: true

  alias GI.Tracking.{Incident, IncidentOccurrence}

  describe "Incident.create_changeset/2" do
    test "valid changeset with all required fields" do
      attrs = %{
        fingerprint: "service_api_timeout",
        title: "API Timeout",
        severity: :critical,
        source: "api-gateway",
        last_occurrence_at: DateTime.utc_now(:second),
        issue_id: Ecto.UUID.generate(),
        account_id: Ecto.UUID.generate()
      }

      changeset = Incident.create_changeset(%Incident{}, attrs)
      assert changeset.valid?
    end

    test "invalid without required fields" do
      changeset = Incident.create_changeset(%Incident{}, %{})
      refute changeset.valid?

      errors = errors_on(changeset)
      assert errors.fingerprint
      assert errors.title
      assert errors.source
      assert errors.last_occurrence_at
      assert errors.issue_id
      assert errors.account_id
    end

    test "validates fingerprint max length" do
      attrs = %{
        fingerprint: String.duplicate("a", 256),
        title: "API Timeout",
        severity: :critical,
        source: "api-gateway",
        last_occurrence_at: DateTime.utc_now(:second),
        issue_id: Ecto.UUID.generate(),
        account_id: Ecto.UUID.generate()
      }

      changeset = Incident.create_changeset(%Incident{}, attrs)
      assert errors_on(changeset).fingerprint
    end

    test "validates title max length" do
      attrs = %{
        fingerprint: "test",
        title: String.duplicate("a", 256),
        severity: :critical,
        source: "api-gateway",
        last_occurrence_at: DateTime.utc_now(:second),
        issue_id: Ecto.UUID.generate(),
        account_id: Ecto.UUID.generate()
      }

      changeset = Incident.create_changeset(%Incident{}, attrs)
      assert errors_on(changeset).title
    end

    test "validates severity inclusion" do
      attrs = %{
        fingerprint: "test",
        title: "Test",
        severity: :invalid,
        source: "test",
        last_occurrence_at: DateTime.utc_now(:second),
        issue_id: Ecto.UUID.generate(),
        account_id: Ecto.UUID.generate()
      }

      changeset = Incident.create_changeset(%Incident{}, attrs)
      assert errors_on(changeset).severity
    end

    test "defaults status to unresolved and muted to false" do
      attrs = %{
        fingerprint: "test",
        title: "Test",
        severity: :info,
        source: "test",
        last_occurrence_at: DateTime.utc_now(:second),
        issue_id: Ecto.UUID.generate(),
        account_id: Ecto.UUID.generate()
      }

      changeset = Incident.create_changeset(%Incident{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :status) == :unresolved
      assert Ecto.Changeset.get_field(changeset, :muted) == false
    end
  end

  describe "Incident.update_changeset/2" do
    test "allows status and muted updates" do
      incident = %Incident{status: :unresolved, muted: false}
      changeset = Incident.update_changeset(incident, %{status: :resolved, muted: true})
      assert changeset.valid?
    end

    test "validates status values" do
      incident = %Incident{status: :unresolved}
      changeset = Incident.update_changeset(incident, %{status: :invalid})
      assert errors_on(changeset).status
    end
  end

  describe "IncidentOccurrence.create_changeset/2" do
    test "valid changeset with context" do
      occurrence = %IncidentOccurrence{
        incident_id: Ecto.UUID.generate(),
        account_id: Ecto.UUID.generate()
      }

      changeset =
        IncidentOccurrence.create_changeset(occurrence, %{
          context: %{"key" => "value"}
        })

      assert changeset.valid?
    end

    test "invalid without incident_id and account_id" do
      changeset = IncidentOccurrence.create_changeset(%IncidentOccurrence{}, %{})
      refute changeset.valid?
      assert errors_on(changeset).incident_id
      assert errors_on(changeset).account_id
    end

    test "validates context max keys" do
      occurrence = %IncidentOccurrence{
        incident_id: Ecto.UUID.generate(),
        account_id: Ecto.UUID.generate()
      }

      big_context = Map.new(1..51, fn i -> {"key_#{i}", "value"} end)

      changeset = IncidentOccurrence.create_changeset(occurrence, %{context: big_context})
      assert errors_on(changeset).context
    end

    test "defaults context to empty map" do
      occurrence = %IncidentOccurrence{
        incident_id: Ecto.UUID.generate(),
        account_id: Ecto.UUID.generate()
      }

      changeset = IncidentOccurrence.create_changeset(occurrence, %{})
      assert Ecto.Changeset.get_field(changeset, :context) == %{}
    end
  end
end
