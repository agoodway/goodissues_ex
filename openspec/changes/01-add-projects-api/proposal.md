# Change: Add Projects API

## Why
The application needs a way to organize work within accounts. Projects provide a logical grouping for issues, enabling multi-tenant accounts to manage multiple products or codebases.

## What Changes
- Add **Projects** capability: CRUD API for projects scoped to accounts
- Projects are account-scoped (multi-tenant)
- New `FF.Tracking` context to house project-related functionality

## Impact
- Affected specs: None (new capability)
- Affected code:
  - New context module: `FF.Tracking`
  - New schema: `FF.Tracking.Project`
  - New migration for `projects` table
  - New API controller: `FFWeb.Api.V1.ProjectController`
  - New OpenAPI schemas for request/response types
  - Router updates for `/api/v1/projects` endpoints
