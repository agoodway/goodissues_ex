# Inspector Review: add-heartbeat-ui

Date: 2026-05-12
Command: `/inspector review-update add-heartbeat-ui`

## Verdict

Ready.

All findings from this review-update pass were auto-patched. No user guidance was required.

## Findings

### Critical

None remaining.

### Warning

None remaining.

### Suggestion

None remaining.

## Patches applied

7 findings were auto-patched. 0 findings were patched after user guidance. 0 findings were skipped.

### Auto-patched

1. **Index ping-event design inconsistency** — `design.md:75` -> Clarified that the index handles `:heartbeat_ping_received` only when the payload changes display state, while the show page prepends matching ping events for the viewed heartbeat.
2. **Create redirect implied automatic token display** — `specs/heartbeat-ui/spec.md:67` -> Changed the redirect scenario to say managers can explicitly reveal the ping URL on the show page.
3. **Advanced create scenario omitted reopen window** — `specs/heartbeat-ui/spec.md:58` -> Added reopen window hours to the advanced create scenario.
4. **Breadcrumb scenarios incomplete** — `specs/heartbeat-ui/spec.md:165` -> Added scenarios for new and edit breadcrumb states.
5. **Create save event guard underspecified** — `tasks.md:28` -> Required a `can_manage` guard inside `HeartbeatLive.New.handle_event("save")` before calling `Monitoring.create_heartbeat/3`.
6. **Ping receipt broadcast needs updated heartbeat state** — `tasks.md:6` -> Added an implementation task to return or reload updated heartbeat state before building `heartbeat_ping_payload/2`.
7. **Clipboard hook risk was stale** — `proposal.md:70` -> Updated the risk to state the existing `CopyToClipboard` hook must be reused with its `data-copy-target` convention.

### User-guided patches

None.

### Skipped

None.

## Validation

`openspec validate add-heartbeat-ui --strict` passed.
