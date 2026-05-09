defmodule GI.Repo.Migrations.CreateTelemetrySpans do
  use Ecto.Migration

  def change do
    create table(:telemetry_spans, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all),
        null: false

      add :request_id, :string
      add :trace_id, :string

      add :event_type, :string, null: false
      add :event_name, :string, null: false
      add :timestamp, :utc_datetime_usec, null: false
      add :duration_ms, :float

      add :context, :map, default: %{}, null: false
      add :measurements, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:telemetry_spans, [:project_id])
    create index(:telemetry_spans, [:request_id])
    create index(:telemetry_spans, [:timestamp])
    create index(:telemetry_spans, [:event_type])
    create index(:telemetry_spans, [:project_id, :request_id])
    create index(:telemetry_spans, [:project_id, :timestamp])
    create index(:telemetry_spans, [:project_id, :event_type, :timestamp])
  end
end
