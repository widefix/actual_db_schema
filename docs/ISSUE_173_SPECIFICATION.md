# Issue #173: Instrumentation for Migration Rollbacks

## Overview

This specification provides a detailed description for implementing ActiveSupport Instrumentation callbacks to track phantom migration rollbacks in the ActualDbSchema gem.

## Problem Statement

Users of ActualDbSchema need to collect statistics and metrics around how many phantom migrations are rolled back by the gem. However, statistics collection is application-specific and should not be part of the gem's core functionality. The solution is to implement [Rails ActiveSupport Instrumentation](https://guides.rubyonrails.org/active_support_instrumentation.html#creating-custom-events) to emit events that applications can subscribe to.

## Use Cases

### 1. Statistics Collection
Track the frequency and patterns of phantom migration rollbacks to understand:
- How often developers switch between branches with conflicting migrations
- Which migrations most frequently cause rollbacks
- Team productivity metrics related to database schema management

### 2. Monitoring and Alerting
- Send notifications to monitoring systems (DataDog, New Relic, etc.)
- Alert teams when rollbacks fail
- Track rollback duration and performance

### 3. Audit Logging
- Maintain a detailed audit trail of all schema changes
- Record which branches and migrations are being rolled back
- Compliance and debugging purposes

### 4. Custom Workflows
- Trigger custom application logic after successful rollbacks
- Integrate with CI/CD pipelines
- Coordinate with deployment tools

## Proposed Solution

Implement ActiveSupport Instrumentation events at key points in the rollback process.

### Event Naming Convention

Following Rails best practices, events should be namespaced under `actual_db_schema`:

1. **`actual_db_schema.rollback_migration.start`** - Fired when a single migration rollback begins
2. **`actual_db_schema.rollback_migration.finish`** - Fired when a single migration rollback completes
3. **`actual_db_schema.rollback_migration.failed`** - Fired when a migration rollback fails
4. **`actual_db_schema.rollback_branches.start`** - Fired when the batch rollback process begins
5. **`actual_db_schema.rollback_branches.finish`** - Fired when the batch rollback process completes

### Event Payloads

#### Individual Migration Events

**`actual_db_schema.rollback_migration.start`**
```ruby
{
  migration_version: "20240115123456",
  migration_name: "AddEmailToUsers",
  migration_filename: "/path/to/db/migrate/20240115123456_add_email_to_users.rb",
  branch: "feature/user-emails",
  database: "primary",
  schema: "public" # or nil if not using multi-tenancy
}
```

**`actual_db_schema.rollback_migration.finish`**
```ruby
{
  migration_version: "20240115123456",
  migration_name: "AddEmailToUsers",
  migration_filename: "/path/to/db/migrate/20240115123456_add_email_to_users.rb",
  branch: "feature/user-emails",
  database: "primary",
  schema: "public", # or nil
  duration: 0.234 # seconds (automatically provided by ActiveSupport)
}
```

**`actual_db_schema.rollback_migration.failed`**
```ruby
{
  migration_version: "20240115123456",
  migration_name: "AddEmailToUsers",
  migration_filename: "/path/to/db/migrate/20240115123456_add_email_to_users.rb",
  branch: "feature/user-emails",
  database: "primary",
  schema: "public", # or nil
  exception: "ActiveRecord::IrreversibleMigration",
  error_message: "This migration uses change_column_null which is not automatically reversible"
}
```

#### Batch Rollback Events

**`actual_db_schema.rollback_branches.start`**
```ruby
{
  phantom_migrations_count: 3,
  databases: ["primary"],
  schemas: ["public", "tenant1", "tenant2"], # or nil
  manual_mode: false
}
```

**`actual_db_schema.rollback_branches.finish`**
```ruby
{
  rolled_back_count: 2,
  failed_count: 1,
  databases: ["primary"],
  schemas: ["public", "tenant1", "tenant2"], # or nil
  manual_mode: false,
  duration: 1.456 # seconds (automatically provided by ActiveSupport)
}
```

## Implementation Points

### Location 1: Individual Migration Rollback
In `lib/actual_db_schema/patches/migration_context.rb`, the `migrate` method (lines 106-119) should be instrumented:

```ruby
def migrate(migration, rolled_back_migrations, schema_name = nil)
  payload = {
    migration_version: migration.version.to_s,
    migration_name: extract_class_name(migration.filename),
    migration_filename: migration.filename,
    branch: branch_for(migration.version.to_s),
    database: ActualDbSchema.db_config[:database],
    schema: schema_name
  }

  ActiveSupport::Notifications.instrument("actual_db_schema.rollback_migration", payload) do
    # existing migration logic
    migration.name = extract_class_name(migration.filename)
    # ... rest of the code
  end
end
```

### Location 2: Error Handling
In the `handle_rollback_error` method (lines 134-148), emit a failure event:

```ruby
def handle_rollback_error(migration, exception, schema_name = nil)
  # existing error handling code
  
  ActiveSupport::Notifications.instrument(
    "actual_db_schema.rollback_migration.failed",
    migration_version: migration.version.to_s,
    migration_name: migration.name,
    migration_filename: migration.filename,
    branch: branch_for(migration.version.to_s),
    database: ActualDbSchema.db_config[:database],
    schema: schema_name,
    exception: exception.class.name,
    error_message: cleaned_exception_message(exception.message)
  )
end
```

### Location 3: Batch Rollback Process
In the `rollback_branches` method (lines 9-21), wrap the entire process:

```ruby
def rollback_branches(manual_mode: false)
  schemas = multi_tenant_schemas&.call || []
  
  payload = {
    phantom_migrations_count: phantom_migrations.count,
    databases: [ActualDbSchema.db_config[:database]],
    schemas: schemas.any? ? schemas : nil,
    manual_mode: manual_mode
  }

  result = nil
  ActiveSupport::Notifications.instrument("actual_db_schema.rollback_branches", payload) do
    # existing rollback logic
    rolled_back_migrations = if schemas.any?
                               rollback_multi_tenant(schemas, manual_mode: manual_mode)
                             else
                               rollback_branches_for_schema(manual_mode: manual_mode)
                             end

    delete_migrations(rolled_back_migrations, schema_count)
    
    # Update payload with results
    payload[:rolled_back_count] = rolled_back_migrations.count
    payload[:failed_count] = ActualDbSchema.failed.count
    
    result = rolled_back_migrations.any?
  end
  
  result
end
```

## Usage Examples

### Example 1: Statistics Collection

```ruby
# config/initializers/actual_db_schema_stats.rb
ActiveSupport::Notifications.subscribe("actual_db_schema.rollback_migration") do |event|
  # Send to your metrics service
  StatsD.increment("actual_db_schema.rollbacks", tags: [
    "branch:#{event.payload[:branch]}",
    "database:#{event.payload[:database]}"
  ])
  
  StatsD.timing("actual_db_schema.rollback_duration", event.duration)
end
```

### Example 2: Audit Logging

```ruby
# config/initializers/actual_db_schema_audit.rb
ActiveSupport::Notifications.subscribe(/actual_db_schema\.rollback_migration/) do |event|
  AuditLog.create(
    event_type: event.name,
    migration_version: event.payload[:migration_version],
    migration_name: event.payload[:migration_name],
    branch: event.payload[:branch],
    database: event.payload[:database],
    success: !event.name.ends_with?("failed"),
    duration: event.duration,
    error_message: event.payload[:error_message],
    occurred_at: Time.current
  )
end
```

### Example 3: Slack Notifications

```ruby
# config/initializers/actual_db_schema_notifications.rb
ActiveSupport::Notifications.subscribe("actual_db_schema.rollback_migration.failed") do |event|
  SlackNotifier.notify(
    channel: "#engineering",
    message: "Migration rollback failed!",
    fields: {
      "Migration": event.payload[:migration_name],
      "Branch": event.payload[:branch],
      "Database": event.payload[:database],
      "Error": event.payload[:error_message]
    }
  )
end
```

### Example 4: Custom Subscriber Class

```ruby
# app/subscribers/actual_db_schema_subscriber.rb
class ActualDbSchemaSubscriber
  def self.subscribe
    ActiveSupport::Notifications.subscribe(/actual_db_schema\./) do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      new.call(event)
    end
  end

  def call(event)
    case event.name
    when "actual_db_schema.rollback_migration"
      handle_rollback(event)
    when "actual_db_schema.rollback_migration.failed"
      handle_failure(event)
    when "actual_db_schema.rollback_branches"
      handle_batch_rollback(event)
    end
  end

  private

  def handle_rollback(event)
    Rails.logger.info(
      "Rolled back migration #{event.payload[:migration_version]} " \
      "from branch #{event.payload[:branch]} in #{event.duration.round(2)}s"
    )
  end

  def handle_failure(event)
    Rails.logger.error(
      "Failed to rollback migration #{event.payload[:migration_version]}: " \
      "#{event.payload[:error_message]}"
    )
  end

  def handle_batch_rollback(event)
    Rails.logger.info(
      "Batch rollback complete: #{event.payload[:rolled_back_count]} succeeded, " \
      "#{event.payload[:failed_count]} failed in #{event.duration.round(2)}s"
    )
  end
end

# In config/initializers/actual_db_schema_subscriber.rb
ActualDbSchemaSubscriber.subscribe
```

## Testing Strategy

### Unit Tests
- Test that events are fired with correct payloads
- Test that events are fired at the right times
- Ensure backward compatibility (instrumentation should be optional)

### Integration Tests
- Verify events work in real rollback scenarios
- Test multi-tenant scenarios emit correct schema information
- Validate error events are fired when rollbacks fail

### Example Test

```ruby
def test_rollback_emits_instrumentation_event
  events = []
  subscriber = ActiveSupport::Notifications.subscribe(/actual_db_schema\.rollback_migration/) do |*args|
    events << ActiveSupport::Notifications::Event.new(*args)
  end

  # Trigger rollback
  perform_rollback

  assert_equal 1, events.length
  event = events.first
  assert_equal "actual_db_schema.rollback_migration", event.name
  assert_equal "20240115123456", event.payload[:migration_version]
  assert event.duration > 0
ensure
  ActiveSupport::Notifications.unsubscribe(subscriber)
end
```

## Documentation Requirements

1. **README Update**: Add a section about instrumentation and observability
2. **Instrumentation Guide**: Create a detailed guide in `/docs/INSTRUMENTATION.md`
3. **Example Configurations**: Provide ready-to-use examples for common monitoring tools
4. **Changelog Entry**: Document the new feature in CHANGELOG.md

## Backward Compatibility

This feature should be 100% backward compatible:
- No breaking changes to existing APIs
- Instrumentation is passive (fire-and-forget)
- Applications not subscribing to events see no change in behavior
- No performance impact if no subscribers are registered

## Benefits

1. **Separation of Concerns**: Statistics and monitoring logic stays in applications
2. **Flexibility**: Applications can implement custom logic without gem changes
3. **Standard Pattern**: Uses Rails conventions that developers already know
4. **Integration Ready**: Works with existing APM and monitoring tools
5. **Testability**: Events can be easily tested and verified
6. **Performance**: Minimal overhead when not subscribed

## References

- [Rails Active Support Instrumentation Guide](https://guides.rubyonrails.org/active_support_instrumentation.html)
- [Creating Custom Events](https://guides.rubyonrails.org/active_support_instrumentation.html#creating-custom-events)
- [Rails Event Store Instrumentation](https://railseventstore.org/docs/advanced-topics/instrumentation/)
- Current implementation: `lib/actual_db_schema/patches/migration_context.rb`
