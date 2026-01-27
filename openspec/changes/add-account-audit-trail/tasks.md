## 1. Audit Trail Infrastructure
- [ ] 1.1 Create audit_logs schema/migration (account_id, action, actor_id, metadata, timestamp)
- [ ] 1.2 Create AuditLog context module with logging functions
- [ ] 1.3 Add audit logging to account create/update/delete operations
- [ ] 1.4 Add audit logging to account status changes (activate/deactivate)
- [ ] 1.5 Add audit logging to role changes

## 2. Audit Trail Display
- [ ] 2.1 Add audit log query functions (by account, with pagination)
- [ ] 2.2 Add activity section to Account Show LiveView
- [ ] 2.3 Display audit entries with timestamp, action, actor, and details
- [ ] 2.4 Add filtering by action type

## 3. Testing
- [ ] 3.1 Write unit tests for audit log context functions
- [ ] 3.2 Write tests for audit log display in Show LiveView
- [ ] 3.3 Verify audit entries are created for all account operations
