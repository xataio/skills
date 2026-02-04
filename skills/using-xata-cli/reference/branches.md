# Branches

Manage database branches with cluster configuration.

## Contents

- [List Branches](#list-branches)
- [View Branch Details](#view-branch-details)
- [Create Branch](#create-branch)
- [Switch Branch](#switch-branch)
- [Get Connection String](#get-connection-string)
- [Wait for Branch Ready](#wait-for-branch-ready)
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

For specific branch:

```bash
xata branch describe --branch <name>
```

**Aliases:** `view`, `show`

## Create Branch

Basic creation:

```bash
xata branch create <name>
```

### Options

```bash
xata branch create <name> \
  --region <region> \
  --instance-type <type> \
  --replicas <0-4> \
  --parent <branch-name> \
  --postgres-version <version> \
  --scale-to-zero \
  --inactivity-period <minutes>
```

| Option                | Description                           |
| --------------------- | ------------------------------------- |
| `--region`            | AWS region (e.g., `us-east-1`)        |
| `--instance-type`     | Size: `small`, `medium`, `large`      |
| `--replicas`          | Read replicas count (0-4)             |
| `--parent`            | Create as child of another branch     |
| `--postgres-version`  | PostgreSQL version                    |
| `--scale-to-zero`     | Enable scale-to-zero for cost savings |
| `--inactivity-period` | Minutes before scaling to zero        |

### Example: Feature Branch

```bash
xata branch create feature-auth --region us-east-1 --parent main
```

### Example: Production Branch

```bash
xata branch create production \
  --region us-east-1 \
  --instance-type large \
  --replicas 2
```

## Switch Branch

```bash
xata branch checkout <name>
```

## Get Connection String

```bash
xata branch url
```

For specific branch:

```bash
xata branch url --branch <name>
```

**Alias:** `connection-string`

## Wait for Branch Ready

Block until branch is healthy:

```bash
xata branch wait-ready
```

With timeout:

```bash
xata branch wait-ready --timeout 300
```

## Delete Branch

```bash
xata branch delete <name>
```

Skip confirmation:

```bash
xata branch delete <name> --force
```

## Branch Hierarchy

View branch tree:

```bash
xata branch tree
```

**Alias:** `topology`

## Branch Configuration

### Get Configuration

```bash
xata branch get <key>
```

### Set Configuration

```bash
xata branch set <key> <value>
```

## Common Patterns

### Feature Branch Workflow

```bash
# Create from main
xata branch create feature-x --parent main

# Wait for it
xata branch wait-ready --branch feature-x

# Switch to it
xata branch checkout feature-x

# Get connection string for app
xata branch url
```

### Cleanup Old Branches

```bash
# List all branches
xata branch list --json | jq -r '.[].name'

# Delete specific branch
xata branch delete old-feature --force
```

## Common Issues

**"Branch not found":** Verify branch name with `xata branch list`. Branch names are case-sensitive.

**Branch creation fails:** Check available regions with `xata regions list`. Verify project context with `xata status`.

**wait-ready times out:** Increase timeout with `--timeout 600`. Check branch health with `xata branch describe --branch <name>`.

**Cannot delete branch:** Ensure branch is not the default. Use `--force` to skip confirmation.

**Connection string not working:** Verify branch is healthy with `xata branch describe`. Check if branch has scaled to zero.
