# Improved Description for Issue #173

## Title
Implement ActiveSupport Instrumentation for Migration Rollback Events

## Description

### Summary
Add ActiveSupport Instrumentation events to track phantom migration rollbacks, enabling applications to collect statistics, monitor performance, and implement custom workflows around the rollback process.

### Problem
Applications using ActualDbSchema need to collect statistics and metrics about phantom migration rollbacks for:
- Monitoring rollback frequency and patterns
- Tracking which migrations are most frequently rolled back
- Alerting on rollback failures
- Maintaining audit logs for compliance
- Measuring team productivity metrics

However, statistics collection is application-specific and should not be part of the gem's core functionality.

### Solution
Implement [Rails ActiveSupport Instrumentation](https://guides.rubyonrails.org/active_support_instrumentation.html#creating-custom-events) to emit events at key points in the rollback process. This allows applications to subscribe to events and implement custom logic without modifying the gem.

### Proposed Events

The following instrumentation events should be added:

1. **`actual_db_schema.rollback_migration`** - Emitted for each individual migration rollback
   - Includes: migration version, name, branch, database, schema, duration
   
2. **`actual_db_schema.rollback_migration.failed`** - Emitted when a rollback fails
   - Includes: migration details plus exception class and error message

3. **`actual_db_schema.rollback_branches`** - Emitted for the complete rollback process
   - Includes: total migrations count, rolled back count, failed count, duration

### Example Usage

Applications can subscribe to these events in an initializer:

```ruby
# config/initializers/actual_db_schema_stats.rb
ActiveSupport::Notifications.subscribe("actual_db_schema.rollback_migration") do |event|
  # Send to monitoring service
  StatsD.increment("db.rollbacks", tags: ["branch:#{event.payload[:branch]}"])
  StatsD.timing("db.rollback_duration", event.duration)
end

ActiveSupport::Notifications.subscribe("actual_db_schema.rollback_migration.failed") do |event|
  # Alert on failures
  Bugsnag.notify("Migration rollback failed", {
    migration: event.payload[:migration_name],
    error: event.payload[:error_message]
  })
end
```

### Benefits

1. **Separation of Concerns**: Monitoring logic stays in applications, not in the gem
2. **Flexibility**: Applications can implement any custom behavior without gem changes
3. **Standard Pattern**: Uses Rails conventions that developers already understand
4. **Zero Overhead**: No performance impact if no subscribers are registered
5. **Integration Ready**: Works seamlessly with APM tools (DataDog, New Relic, Skylight, etc.)
6. **100% Backward Compatible**: No breaking changes, completely optional feature

### Implementation Details

See the complete specification document: [`docs/ISSUE_173_SPECIFICATION.md`](./ISSUE_173_SPECIFICATION.md)

The specification includes:
- Detailed event payload structures
- Specific implementation points in the codebase
- Comprehensive usage examples (statistics, audit logging, Slack notifications)
- Testing strategy
- Documentation requirements

### Acceptance Criteria

- [ ] Events are emitted at correct points in the rollback process
- [ ] Event payloads contain all necessary information
- [ ] Events work correctly in multi-tenant scenarios
- [ ] No performance impact when no subscribers are present
- [ ] 100% backward compatible - no breaking changes
- [ ] Documentation includes examples for common use cases
- [ ] Tests verify events are emitted with correct payloads

### References
- [Rails Active Support Instrumentation Guide](https://guides.rubyonrails.org/active_support_instrumentation.html)
- [Creating Custom Events](https://guides.rubyonrails.org/active_support_instrumentation.html#creating-custom-events)
- [Complete Specification](./ISSUE_173_SPECIFICATION.md)
