# Change: Add Issues API

## Why
The application needs a way to track bugs and feature requests. Issues provide a structured way to capture, prioritize, and track work items within projects.

## What Changes
- Add **Issues** capability: CRUD API for issues with:
  - Type: bug, feature_request
  - Status: new, in_progress, archived
  - Priority: low, medium, high, critical
  - Submitter tracking (user reference + optional email)
- Issues require a project assignment (depends on 01-add-projects-api)
- Issues are account-scoped through their project relationship

## Impact
- Affected specs: None (new capability)
- Affected code:
  - New schema: `GI.Tracking.Issue`
  - New migration for `issues` table
  - New API controller: `GIWeb.Api.V1.IssueController`
  - New OpenAPI schemas for request/response types
  - Router updates for `/api/v1/issues` endpoints
  - Extend `GI.Tracking` context with issue functions

## Dependencies
- Requires 01-add-projects-api to be implemented first
