# Branches

Manage database branches with cluster configuration.

Most branch subcommands accept the target branch either as a positional argument or via `--branch <id>`. They also accept `--organization` and `--project` to override the linked values.

## Contents

- [List Branches](#list-branches)
- [View Branch Details](#view-branch-details)
- [Create Branch](#create-branch)
- [Switch Branch](#switch-branch)
- [Get Connection String](#get-connection-string)
- [Wait for Branch Ready](#wait-for-branch-ready)
- [Branch Metrics](#branch-metrics)
- [Branch Logs](#branch-logs)
- [Rotate Password](#rotate-password)
- [Delete Branch](#delete-branch)
- [Branch Hierarchy](#branch-hierarchy)
- [Branch Configuration](#branch-configuration)
- [Common Patterns](#common-patterns)
- [Common Issues](#common-issues)

## List Branches

```bash
xata branch list
```

**Alias:** `ls`

JSON output:

```bash
xata branch list --json
```

## View Branch Details

```bash
xata branch describe
```

For a specific branch (positional or flag):

```bash
xata branch describe <name>
xata branch describe --branch <name>
```

**Aliases:** `view`, `show`

## Create Branch

Interactive creation (the CLI prompts for any option you leave out):

```bash
xata branch create
```

### Options

```bash
xata branch create \
  --name <name> \
  --parent-branch <branch-id> \
  --region <region> \
  --instance-type <type> \
  --replicas <0-4> \
  --postgres-version <version> \
  --scale-to-zero <true|false> \
  --inactivity-period <15|30|60|120|180>
```

| Option               | Description                                                            |
| -------------------- | --------------------------------------------------------------------- |
| `--name`             | Branch name                                                           |
| `--parent-branch`    | Parent branch ID. Pass `None` to create a branch without a parent.    |
| `--region`           | Region for the branch                                                 |
| `--instance-type`    | Instance type for the branch                                          |
| `--replicas`         | Number of read replicas (`0`–`4`)                                     |
| `--postgres-version` | PostgreSQL version (defaults to the latest available)                 |
| `--scale-to-zero`    | Scale-to-zero status, `true` or `false`                              |
| `--inactivity-period`| Minutes before scaling to zero (`15`, `30`, `60`, `120`, or `180`)   |

### Example: Feature Branch

```bash
xata branch create --name feature-auth --parent-branch main --region us-east-1
```

## Switch Branch

Switch the locally-configured working branch:

```bash
xata branch checkout <name>
```

`xata checkout <name>` is a top-level shortcut for the same command.

## Get Connection String

```bash
xata branch url
```

For a specific branch and/or database:

```bash
xata branch url <name> --database <db>
```

**Alias:** `connection-string`

### Connection Type

Use `--type` to choose how the connection string routes:

| `--type` value         | Description                                          |
| ---------------------- | ---------------------------------------------------- |
| `primary` (default)    | Direct access to the primary                         |
| `primary-or-replica`   | Routed access to primary or replicas                 |
| `replica`              | Read-only access to replicas only                    |
| `pooler`               | Pooled access to the primary                         |

```bash
xata branch url --type pooler
```

## Wait for Branch Ready

Block until a branch is ready:

```bash
xata branch wait-ready
xata branch wait-ready <name>
```

Wake a hibernated branch while waiting:

```bash
xata branch wait-ready <name> --wake
```

## Branch Metrics

Show CPU, memory, and other metrics for a branch:

```bash
xata branch metrics
xata branch metrics <name>
```

Useful flags:

| Flag              | Description                                                                  |
| ----------------- | --------------------------------------------------------------------------- |
| `--since`         | Time range ending now, e.g. `1h`, `24h`, `7d`                               |
| `--start` / `--end`| Start/end as ISO timestamps                                                |
| `--metrics`       | `default`, `all`, or a comma-separated list (default `default`)             |
| `--instances`     | `all`, `primary`, `replicas`, or comma-separated instance IDs (default `all`)|
| `--aggregations`  | Comma-separated `avg,max,min` (default `avg,max,min`)                        |
| `--aggregation`   | Single aggregation to render in table/TUI output (`avg`, `max`, or `min`)   |
| `--output`, `-o`  | Output format: `table`, `json`, `ndjson`, or `tui` (default `table`)        |
| `--watch`, `-w`   | Refresh metrics continuously                                                |
| `--refresh`       | Refresh interval for watch mode, e.g. `10s`, `1m`, `500ms` (default `10s`)  |

```bash
xata branch metrics --since 1h --watch
```

## Branch Logs

Retrieve database logs for a branch (defaults to the last hour):

```bash
xata branch logs
xata branch logs <name>
```

Useful flags:

| Flag             | Description                                                                  |
| ---------------- | ---------------------------------------------------------------------------- |
| `--level`        | Filter by level (`debug`, `info`, `warning`, `error`); repeatable            |
| `--instance`     | Filter by branch instance ID; repeatable                                     |
| `--process`      | Filter by process name; repeatable                                           |
| `--search`       | Case-insensitive substring search in the message body                        |
| `--start` / `--end`| Time bounds as ISO timestamps or relative durations (e.g. `15m`, `1h`, `7d`); `--start` defaults to 1h ago |
| `--limit`        | Maximum logs to fetch, up to `1000` (default `100`)                          |
| `--follow`, `-f` | Poll for new logs continuously                                               |
| `--output`, `-o` | Output format: `raw`, `json`, `ndjson`, or `csv` (default `raw`)             |

```bash
# Errors from the last 24h, followed live
xata branch logs --level error --start 24h --follow

# Regex filtering: pipe raw output to rg/grep
xata branch logs --output raw | rg 'timeout|deadlock'
```

## Rotate Password

Rotate the database password for a branch:

```bash
xata branch rotate-password <name>
```

Skip the confirmation prompt with `--yes`.

## Delete Branch

```bash
xata branch delete <name>
```

Skip confirmation:

```bash
xata branch delete <name> --yes
```

You can also target a branch by ID with `--branch <id>`.

## Branch Hierarchy

View the branch tree:

```bash
xata branch tree
```

**Alias:** `topology`. Add `--show-id` to include branch IDs.

## Branch Configuration

`xata branch get` / `xata branch set` read and write branch fields. Settable fields: `replicas`, `instance-type`, `scale-to-zero`, `inactivity-period`, `postgres-version`.

### Get a Field

```bash
xata branch get <field>
```

### Set a Field

```bash
xata branch set <field> <value>
```

```bash
xata branch set postgres-version 17
xata branch set replicas 2
```

## Common Patterns

### Feature Branch Workflow

```bash
# Create from main
xata branch create --name feature-x --parent-branch main

# Wait for it
xata branch wait-ready feature-x

# Switch to it
xata branch checkout feature-x

# Get connection string for the app
xata branch url
```

### Cleanup Old Branches

```bash
# List all branches
xata branch list --json | jq -r '.[].name'

# Delete a specific branch
xata branch delete old-feature --yes
```

## Common Issues

**"Branch not found":** Verify the branch name with `xata branch list`. Branch names are case-sensitive.

**Branch creation fails:** Re-run `xata branch create` interactively so the CLI offers valid regions and instance types. Verify project context with `xata status`.

**wait-ready never returns:** The branch may be hibernated. Re-run with `--wake`, and check branch health with `xata branch describe <name>`.

**Cannot delete branch:** Ensure the branch is not the default. Use `--yes` to skip confirmation.

**Connection string not working:** Verify the branch is ready with `xata branch describe`. If it scaled to zero, run `xata branch wait-ready <name> --wake`.
