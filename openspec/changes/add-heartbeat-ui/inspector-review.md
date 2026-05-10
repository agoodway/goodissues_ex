# Inspector Review: add-heartbeat-ui

Date: 2026-05-10
Command: `/inspector review-update add-heartbeat-ui`

## Verdict

Ready.

All review findings were patched, including one user-guided design decision for heartbeat ping URL token reveal.

## Findings

### Critical

None remaining.

### Warning

None remaining.

### Suggestion

None remaining.

## Patches applied

11 findings were patched. 10 findings were auto-patched. 1 finding was patched after user guidance. 0 findings were skipped.

### Auto-patched

1. **Heartbeat ping events missing from index tasks** — `tasks.md:18` -> Added `:heartbeat_ping_received` handling to `HeartbeatLive.Index` tasks and realtime test coverage.
2. **Ping history filtering missing backend support** — `tasks.md:7` -> Added `list_heartbeat_pings/2` kind filtering task and context test coverage so filtering occurs before pagination.
3. **Deadline/runtime status changes missing PubSub coverage** — `design.md:46` -> Added runtime status broadcast requirement, preferably centralized through `update_heartbeat_runtime/2`, with test coverage.
4. **Heartbeat PubSub payload shape unspecified** — `tasks.md:5` -> Added payload helper task and design-level payload contracts for heartbeat and ping events.
5. **Paused treated as persisted status** — `specs/heartbeat-ui/spec.md:4` -> Clarified effective display status uses `paused=true` before falling back to persisted `up/down/unknown` status.
6. **Endpoint token naming and method copy ambiguity** — `specs/heartbeat-ui/spec.md:78` -> Replaced `:token` with `:heartbeat_token` and specified that `POST` is a separate method label while copy copies only the URL.
7. **Existing clipboard hook convention mismatch** — `tasks.md:11` -> Updated design/tasks to reuse the existing `CopyToClipboard` `data-copy-target` input convention.
8. **Event-level authorization underspecified** — `tasks.md:33` -> Added explicit `can_manage` guard tasks for edit params, save, delete, and pause/resume events.
9. **Authorization tests missing** — `tasks.md:42` -> Added LiveView coverage for hidden manager-only controls, direct non-manager mutation attempts, non-manager access denial, and token reveal hiding.
10. **Breadcrumb implementation/testing missing** — `specs/heartbeat-ui/spec.md:160` -> Added breadcrumb implementation task and LiveView assertions.

### User-guided patches

1. **Ping URL display conflicts with canonical token redaction** — `specs/heartbeat-ui/spec.md:77` -> Added an explicit manager-only ping URL reveal capability, updated UI requirements to reveal only on manager request, and added a `heartbeat-monitoring` delta preserving normal management read redaction. User chose: manager reveal endpoint.

### Skipped

None.

## Validation

`openspec validate add-heartbeat-ui --strict` passed.
