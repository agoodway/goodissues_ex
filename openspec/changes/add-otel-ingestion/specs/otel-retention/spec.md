## ADDED Requirements

### Requirement: Per-project retention TTL
The system SHALL support a configurable `retention_days` field on projects with a default of 30 days and a minimum of 1 day.

#### Scenario: Default retention period
- **WHEN** a project is created without specifying `retention_days`
- **THEN** the project has a default retention period of 30 days

#### Scenario: Custom retention period
- **WHEN** a project is updated with `retention_days` = 90
- **THEN** OTel data older than 90 days is eligible for pruning

#### Scenario: Minimum retention period enforced
- **WHEN** a project is updated with `retention_days` = 0
- **THEN** the update fails with a validation error because the minimum is 1 day

### Requirement: Automated OTel data pruning
The system SHALL run a daily Oban cron job that deletes OTel spans and metrics older than each project's configured `retention_days`.

#### Scenario: Prune expired spans
- **WHEN** the retention pruner runs for a project with `retention_days` = 30
- **THEN** all `otel_spans` with `start_time` older than 30 days ago are deleted for that project
- **AND** recent spans within the retention window are preserved

#### Scenario: Prune expired metrics
- **WHEN** the retention pruner runs for a project with `retention_days` = 30
- **THEN** all `otel_metrics` with `timestamp` older than 30 days ago are deleted for that project
- **AND** recent metrics within the retention window are preserved

#### Scenario: Batch deletion to avoid long locks
- **WHEN** a project has a large volume of expired OTel data
- **THEN** the pruner deletes in batches (e.g., 1000 rows per batch) to avoid table-level locks
- **AND** continues until all expired data is removed

#### Scenario: No data to prune
- **WHEN** the retention pruner runs and no OTel data exceeds the retention window
- **THEN** zero rows are deleted and the job completes successfully

#### Scenario: Pruner runs for all projects
- **WHEN** the daily retention pruner executes
- **THEN** it iterates over all projects with OTel data and applies each project's `retention_days` independently
