## RENAMED Requirements

### Requirement: Project branding
FROM: GoodIssues / FF / goodissues
TO: GoodIssues / GI / goodissues

All user-facing brand references, module prefixes, OTP app names, CLI binary names, email domains, and documentation SHALL use the new "GoodIssues" naming consistently.

#### Scenario: Elixir modules use GI prefix
- **WHEN** any Elixir module is referenced
- **THEN** the module prefix SHALL be `GI` (business logic) or `GIWeb` (web layer)

#### Scenario: OTP app name is good_issues
- **WHEN** the application is configured or started
- **THEN** the OTP app name SHALL be `:good_issues`

#### Scenario: CLI binary is goodissues
- **WHEN** a user invokes the CLI
- **THEN** the binary name SHALL be `goodissues`

#### Scenario: CLI config directory is goodissues
- **WHEN** the CLI reads or writes configuration
- **THEN** the config directory SHALL be `~/.goodissues/`

#### Scenario: Email domains use goodissues.dev
- **WHEN** the system sends emails or references email addresses
- **THEN** the domain SHALL be `goodissues.dev` (external) or `goodissues.internal` (bot users)
