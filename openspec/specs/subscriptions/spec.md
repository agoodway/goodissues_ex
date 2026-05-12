## ADDED Requirements

### Requirement: Telegram subscription channel
The system SHALL support `telegram` as a valid event subscription channel alongside `email` and `webhook`.

#### Scenario: Create Telegram subscription
- **WHEN** an authorized account manager creates a subscription with channel `telegram`, at least one valid event type, and a valid static Telegram chat ID destination
- **THEN** the system creates the Telegram subscription for the current account

#### Scenario: List Telegram subscription
- **WHEN** an account user lists subscriptions for an account containing Telegram subscriptions
- **THEN** the system includes Telegram subscriptions in the account-scoped list with channel `telegram`

### Requirement: Telegram subscriptions require static chat ID destinations
Telegram subscriptions SHALL require a static `destination` containing a Telegram chat ID and SHALL NOT allow `user_id` linked destinations.

#### Scenario: Telegram destination accepted
- **WHEN** a Telegram subscription uses a destination matching `^-?\d+$` and no `user_id`
- **THEN** the subscription validation succeeds for the destination fields

#### Scenario: Telegram destination missing
- **WHEN** a Telegram subscription is submitted without a destination
- **THEN** the system rejects the subscription with a destination validation error

#### Scenario: Telegram destination invalid
- **WHEN** a Telegram subscription destination does not match `^-?\d+$`
- **THEN** the system rejects the subscription with a Telegram chat ID validation error

#### Scenario: Telegram user linked destination rejected
- **WHEN** a Telegram subscription is submitted with `user_id`
- **THEN** the system rejects the subscription because Telegram supports static chat IDs only

### Requirement: Telegram dashboard subscription management
The dashboard subscription management UI SHALL allow authorized account managers to create, view, toggle, and delete Telegram subscriptions. Telegram forms SHALL label the destination field as a Telegram chat ID and provide help text for finding a chat ID.

#### Scenario: Telegram appears in channel options
- **WHEN** an authorized account manager opens the new subscription form
- **THEN** Telegram is available as a channel option

#### Scenario: Telegram chat ID help text
- **WHEN** the new subscription form channel is Telegram
- **THEN** the destination input is labeled as a Telegram chat ID
- **AND** the form shows help text explaining how to find a Telegram chat ID (e.g., send `/start` to the bot and use the Telegram `getUpdates` API or a chat ID bot to retrieve the numeric ID)

#### Scenario: Telegram row rendering
- **WHEN** the subscriptions list contains a Telegram subscription
- **THEN** the row displays Telegram as the channel and shows the static chat ID destination

### Requirement: Telegram subscriptions API support
The subscriptions REST API SHALL include `telegram` in the subscription channel enum and SHALL enforce Telegram-specific static chat ID validation on create, update, list, show, delete, and test operations.

#### Scenario: API creates Telegram subscription
- **WHEN** an API client with `subscriptions:write` creates a Telegram subscription with a valid chat ID destination
- **THEN** the API returns `201` with the created subscription and channel `telegram`
- **AND** the response does not include a webhook secret for the Telegram subscription

#### Scenario: API rejects linked Telegram user
- **WHEN** an API client creates or updates a Telegram subscription with `user_id`
- **THEN** the API returns `422` with validation errors

#### Scenario: API omits secret for Telegram subscriptions
- **WHEN** the API serializes a Telegram subscription for show or list responses
- **THEN** the response does not include a `secret` field

#### Scenario: API lists Telegram subscriptions
- **WHEN** an API client with `subscriptions:read` lists subscriptions for an account containing Telegram subscriptions
- **THEN** the API response includes Telegram subscriptions in the paginated result

#### Scenario: API tests Telegram subscription
- **WHEN** an API client with `subscriptions:write` invokes the test endpoint for an active Telegram subscription
- **THEN** the system sends a synthetic event through the Telegram delivery pipeline and returns the delivery status

### Requirement: Subscription API documentation includes Telegram
The OpenAPI subscription schemas SHALL document `telegram` as a valid subscription channel and SHALL describe Telegram-specific validation for static chat ID destinations.

#### Scenario: OpenAPI channel enum includes Telegram
- **WHEN** the OpenAPI specification is generated
- **THEN** the subscription channel schema includes `telegram`

#### Scenario: OpenAPI request docs describe Telegram destination
- **WHEN** an API consumer reads the subscription create or update schema
- **THEN** the schema description explains that Telegram subscriptions require a static chat ID destination and do not support `user_id`
