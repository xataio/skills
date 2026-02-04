# Schema Migrations

PostgreSQL schema migrations using pgroll.

## Contents

- [Initialize](#initialize)
- [Migration Workflow](#migration-workflow)
- [Quick Migrate](#quick-migrate)
- [Check Status](#check-status)
- [Baseline Existing Database](#baseline-existing-database)
- [Pull Current Schema](#pull-current-schema)
- [View Latest](#view-latest)
- [Update Migration](#update-migration)
- [Convert Formats](#convert-formats)
- [Common Migration Operations](#common-migration-operations)
- [Common Issues](#common-issues)

## Initialize

Set up migrations directory structure:

```bash
xata roll init
```

With custom directory:

```bash
xata roll init --directory ./migrations
```

## Migration Workflow

### 1. Create Migration File

Migrations are JSON files describing schema changes. Example `001_add_users.json`:

```json
{
  "name": "001_add_users",
  "operations": [
    {
      "create_table": {
        "name": "users",
        "columns": [
          { "name": "id", "type": "serial", "pk": true },
          { "name": "email", "type": "text", "unique": true },
          { "name": "created_at", "type": "timestamptz", "default": "now()" }
        ]
      }
    }
  ]
}
```

### 2. Start Migration

Begin migration (creates new schema version):

```bash
xata roll start 001_add_users.json
```

### 3. Test Changes

Your app can now use the new schema while old schema remains available.

### 4. Complete Migration

Finalize when ready:

```bash
xata roll complete
```

### 5. Or Rollback

If issues found:

```bash
xata roll rollback
```

## Quick Migrate

Start and complete in one step:

```bash
xata roll migrate <migration-file>
```

## Check Status

```bash
xata roll status
```

JSON output:

```bash
xata roll status --json
```

## Baseline Existing Database

For databases with existing schema:

```bash
xata roll baseline
```

## Pull Current Schema

Sync schema from database to local files:

```bash
xata roll pull
```

With output path:

```bash
xata roll pull --output ./schema.json
```

## View Latest

### Current Schema

```bash
xata roll latest schema
```

### Current Migration

```bash
xata roll latest migration
```

## Update Migration

Modify an in-progress migration:

```bash
xata roll update <migration-file>
```

## Convert Formats

Convert between migration formats:

```bash
xata roll convert <input-file> --format <format>
```

## Common Migration Operations

### Add Column

```json
{
  "operations": [
    {
      "add_column": {
        "table": "users",
        "column": { "name": "phone", "type": "text", "nullable": true }
      }
    }
  ]
}
```

### Add Index

```json
{
  "operations": [
    {
      "create_index": {
        "name": "idx_users_email",
        "table": "users",
        "columns": ["email"]
      }
    }
  ]
}
```

### Rename Column

```json
{
  "operations": [
    {
      "rename_column": {
        "table": "users",
        "from": "phone",
        "to": "phone_number"
      }
    }
  ]
}
```

## Common Issues

**Migration stuck:** Check status with `xata roll status`, then either `complete` or `rollback`

**Schema conflict:** Pull latest with `xata roll pull` and compare with your migration

**Rollback failed:** Check database state, may need manual intervention

**"Migration already in progress":** Complete or rollback the existing migration with `xata roll complete` or `xata roll rollback`

**Invalid migration file:** Validate JSON syntax. Check operation names match pgroll schema (e.g., `create_table`, `add_column`)

**Migration not found:** Ensure file path is correct. Run `xata roll init` if migrations directory doesn't exist
