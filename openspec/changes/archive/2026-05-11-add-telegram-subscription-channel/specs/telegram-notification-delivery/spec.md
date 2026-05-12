## ADDED Requirements

### Requirement: Telegram delivery worker
The system SHALL enqueue Telegram notification deliveries to a dedicated Oban worker when an active Telegram subscription matches an emitted event.

#### Scenario: Matching Telegram subscription enqueues delivery
- **WHEN** an event is emitted for an account with an active matching Telegram subscription
- **THEN** the listener enqueues a Telegram delivery job with the event data, account ID, subscription ID, and Telegram chat ID destination

### Requirement: Telegram Bot API client
The system SHALL send Telegram messages through a configurable Telegram client behavior. The HTTP implementation SHALL use Req to call Telegram Bot API `sendMessage` with MarkdownV2 parse mode.

#### Scenario: Successful Telegram API response
- **WHEN** Telegram returns a successful `sendMessage` response
- **THEN** the Telegram client returns success to the delivery worker

#### Scenario: Failed Telegram API response
- **WHEN** Telegram returns a non-success response or the request fails
- **THEN** the Telegram client returns an error containing the failed status or reason

### Requirement: Telegram delivery uses account bot token
The Telegram delivery worker SHALL load the Telegram profile for the event account and use that account's decrypted bot token for delivery. If the account has no Telegram profile, the worker SHALL cancel the job without retrying and log a failed delivery.

#### Scenario: Account has Telegram profile
- **WHEN** a Telegram delivery job runs for an account with a Telegram profile
- **THEN** the worker sends the message using that account's bot token
- **AND** the system logs the delivery with channel `telegram`

#### Scenario: Account has no Telegram profile
- **WHEN** a Telegram delivery job runs for an account without a Telegram profile
- **THEN** the worker records a failed Telegram delivery
- **AND** the worker cancels the job without retrying

### Requirement: Telegram chat ID validation at delivery
The Telegram delivery worker SHALL validate Telegram destinations as integer chat IDs before calling Telegram. Invalid chat IDs SHALL fail without retrying.

#### Scenario: Invalid chat ID
- **WHEN** a Telegram delivery job has a destination that does not match `^-?\d+$`
- **THEN** the worker records a failed Telegram delivery
- **AND** the worker cancels the job without calling Telegram

### Requirement: Telegram MarkdownV2 message formatting
The system SHALL build Telegram-specific MarkdownV2 message bodies for all current GoodIssues event types and SHALL escape dynamic content according to Telegram MarkdownV2 rules.

#### Scenario: Issue event message
- **WHEN** the system builds a Telegram message for an issue event
- **THEN** the message includes a GoodIssues heading and issue-specific event details formatted as MarkdownV2

#### Scenario: Error event message
- **WHEN** the system builds a Telegram message for an error event
- **THEN** the message includes a GoodIssues heading and error-specific event details formatted as MarkdownV2

#### Scenario: Dynamic content escaping
- **WHEN** event data contains Telegram MarkdownV2 control characters
- **THEN** the formatter escapes those characters before sending the message

### Requirement: Telegram delivery logging
The system SHALL accept `telegram` as a valid notification log channel. The system SHALL write notification logs for Telegram delivery attempts using channel `telegram`, the subscription ID, destination chat ID, status, resource fields, and any failure reason.

#### Scenario: Successful Telegram delivery log
- **WHEN** Telegram delivery succeeds
- **THEN** the system records a notification log with status `delivered` and channel `telegram`

#### Scenario: Failed Telegram delivery log
- **WHEN** Telegram delivery fails
- **THEN** the system records a notification log with status `failed`, channel `telegram`, and a sanitized error message
