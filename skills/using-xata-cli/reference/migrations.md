# Schema Migrations

PostgreSQL schema migrations using pgroll. The `xata roll` commands wrap the bundled `pgroll` binary, so they accept pgroll's flags (e.g. `--postgres-url`, `--pgroll-schema`, `--lock-timeout`, `--role`, `--schema`). The CLI runs them against the current project's branch.

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

Set up the migrations table in the target branch:

```bash
xata roll init
```

## Migration Workflow

### 1. Create a Migration File

Migrations are JSON (or YAML) files describing schema changes. Example `001_add_users.json`:

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

### 2. Start the Migration

Begin a migration (creates a new, parallel schema version):

```bash
xata roll start 001_add_users.json
```

### 3. Test the Changes

Your app can use the new schema version while the old version stays available, so you can roll out clients gradually.

### 4. Complete the Migration

Finalize when ready:

```bash
xata roll complete
```

### 5. Or Roll Back

If issues are found before completing:

```bash
xata roll rollback
```

## Quick Migrate

Apply every migration in a folder. `migrate` takes the migrations directory (default is the project's migrations folder), and `--complete` also completes the last migration:

```bash
xata roll migrate ./migrations
xata roll migrate ./migrations --complete
```

## Check Status

```bash
xata roll status
```

## Baseline Existing Database

Capture the current state of a database that already has a schema as the first migration:

```bash
xata roll baseline <version-name> ./migrations
```

For example: `xata roll baseline 01_initial_schema ./migrations`.

## Pull Current Schema

Pull the applied migration history from the database into a local folder:

```bash
xata roll pull ./migrations
```

## View Latest

```bash
# Latest schema version (migration name prefixed with the schema)
xata roll latest schema

# Latest migration name (without the schema prefix)
xata roll latest migration
```

## Update Migration

Update/normalize migration files in a directory:

```bash
xata roll update ./migrations
```

## Convert Formats

Convert a plain-SQL migration file into pgroll's JSON format:

```bash
xata roll convert <input-file>
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

**Migration stuck:** Check `xata roll status`, then either `xata roll complete` or `xata roll rollback`.

**"Migration already in progress":** Complete or roll back the active migration before starting a new one.

**Schema conflict:** Pull the latest history with `xata roll pull` and compare with your migration.

**Invalid migration file:** Validate the JSON. Check operation names against the pgroll schema (e.g. `create_table`, `add_column`).

**Branch not reachable:** The CLI must reach the branch's Postgres endpoint. If the branch scaled to zero, wake it with `xata branch wait-ready <name> --wake` first.
