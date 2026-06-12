# Database Cloning

Clone another PostgreSQL database into your current Xata branch, with optional anonymization. These commands wrap the bundled `pgstream` binary.

## Contents

- [Overview](#overview)
- [Generate the Transform Config](#generate-the-transform-config)
- [Start a Clone](#start-a-clone)
- [Continuous Stream](#continuous-stream)
- [Shared Flags](#shared-flags)
- [Config File](#config-file)
- [Common Patterns](#common-patterns)
- [Common Issues](#common-issues)

## Overview

Xata clone copies structure and data from a source database (`--source-url`) into the branch configured for the current project (or the one passed with `--branch`). There is no separate target flag: the clone always lands in the Xata branch. Optionally, column transformers anonymize sensitive data as it is copied.

The workflow is:

1. Generate an anonymization config with `xata clone config`.
2. Run `xata clone start` (one-shot) or `xata clone stream` (continuous).

## Generate the Transform Config

```bash
xata clone config --source-url <postgres-url>
```

The `--mode` flag controls how the config is generated:

| `--mode` value | Behavior                                                                  |
| -------------- | ------------------------------------------------------------------------- |
| `auto`         | Generate a config automatically with sensible defaults                    |
| `prompt`       | Interactive prompts (terminal)                                            |
| `web`          | Open a browser-based helper                                               |
| `ai`           | Use AI to detect likely PII and pick transformers                         |

For AI mode you can steer it with `--prompt`:

```bash
xata clone config --source-url <url> --mode ai --prompt "anonymize email and phone columns"
```

The generated config is written to `.xata/clone.yaml`. Review and edit it before cloning. Use `--validation-mode` (`strict`, `relaxed`, or `prompt`) to control how strictly tables/columns must be specified.

## Start a Clone

One-shot clone of the source into the current branch:

```bash
xata clone start --source-url <postgres-url>
```

With anonymization and roles copied:

```bash
xata clone start \
  --source-url postgres://user:pass@host:5432/db \
  --validation-mode strict \
  --copy-roles
```

## Continuous Stream

`xata clone stream` keeps streaming changes from the source (change data capture) rather than doing a single snapshot:

```bash
xata clone stream --source-url <postgres-url>
```

Stream supports `--replication-slot <name>` and `--skip-ddl-tracking` for managed Postgres services that do not allow the superuser access needed for event triggers.

## Shared Flags

`start` and `stream` accept:

| Flag                | Description                                                            |
| ------------------- | --------------------------------------------------------------------- |
| `--source-url`      | Source database URL to clone/stream from (required)                   |
| `--branch`          | Target Xata branch ID (defaults to the linked branch)                 |
| `--filter-tables`   | Tables to include, e.g. `public.*` (default `*.*`)                    |
| `--validation-mode` | `strict`, `relaxed`, or `prompt`                                      |
| `--role`            | Postgres role to use (stream's role needs `REPLICATION` privilege)    |
| `--log-level`       | `trace`, `debug`, `info`, `warn`, `error`, `fatal`, or `panic`        |
| `--copy-roles`      | Copy roles, owners, and privileges to the target                      |

## Config File

`.xata/clone.yaml` follows pgstream's transformations format: a `validation_mode` plus `table_transformers`, where each table lists `column_transformers` keyed by column. Columns with no transformer use `noop` (copied as-is). Run `xata clone config` again to regenerate it.

## Common Patterns

### Anonymized Production Copy

```bash
# 1. Generate an AI-assisted anonymization config
xata clone config --source-url $PROD_URL --mode ai

# 2. Review/edit .xata/clone.yaml

# 3. Clone into the current branch
xata clone start --source-url $PROD_URL --validation-mode strict
```

### Plain Copy (No Anonymization)

```bash
xata clone config --source-url $SRC_URL --mode auto
xata clone start --source-url $SRC_URL
```

## Common Issues

**Validation errors:** Tighten or relax `--validation-mode`. In `strict` mode every table and column must have an explicit transformer in `.xata/clone.yaml`.

**Missing tables:** Check `--filter-tables` (default `*.*`) and the table list in `.xata/clone.yaml`.

**Stream cannot create a replication slot:** Pass `--skip-ddl-tracking` with a pre-created `--replication-slot`, and ensure `--role` has `REPLICATION` privilege.

**Source not reachable:** Verify `--source-url` credentials and network access from where you run the CLI.
