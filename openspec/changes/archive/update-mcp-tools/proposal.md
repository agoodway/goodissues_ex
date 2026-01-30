# Change: Update MCP Server Tools for Issues and Projects

## Why
The MCP server currently exposes tools for accounts and API keys, which are administrative functions not useful for AI assistants. Instead, the MCP server should expose tools for projects and issues, which are the core domain operations that AI assistants need to interact with.

## What Changes
- **REMOVED** accounts_list, accounts_get, accounts_users_list, api_keys_list tools
- **ADDED** projects_list tool - List projects in the account
- **ADDED** projects_get tool - Get a specific project by ID
- **ADDED** issues_list tool - List issues with filtering and pagination
- **ADDED** issues_get tool - Get a specific issue by ID
- **ADDED** issues_create tool - Create a new issue
- **ADDED** issues_update tool - Update an existing issue

## Impact
- Affected specs: mcp-server (new capability)
- Affected code:
  - `app/lib/app_web/mcp/server.ex` - Update component registrations
  - `app/lib/app_web/mcp/tools/accounts/` - Remove entire directory
  - `app/lib/app_web/mcp/tools/projects/` - New directory with project tools
  - `app/lib/app_web/mcp/tools/issues/` - New directory with issue tools
