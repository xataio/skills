---
name: using-xata-cli
description: Manages Xata serverless PostgreSQL databases via the xata CLI. Use when working with Xata projects, branches, organizations, authentication, schema migrations (pgroll), data cloning, or AI-powered SQL. Triggers on xata commands, database branch management, project setup, schema migrations, team management, connection strings, or any Xata database administration tasks.
---

# Using Xata CLI

## Quick Reference

**What do you need to do?**

| Task                                    | Reference                                        |
| --------------------------------------- | ------------------------------------------------ |
| Login, switch profiles, manage tokens   | [reference/auth.md](reference/auth.md)           |
| Create, configure, or link projects     | [reference/projects.md](reference/projects.md)   |
| Create, checkout, or delete branches    | [reference/branches.md](reference/branches.md)   |
| Schema migrations with pgroll           | [reference/migrations.md](reference/migrations.md) |
| Manage organizations and team members   | [reference/organizations.md](reference/organizations.md) |
| Create or manage API keys               | [reference/keys.md](reference/keys.md)           |
| Clone databases with anonymization      | [reference/clone.md](reference/clone.md)         |

## Prerequisites

**Required:** Xata CLI installed (`npm install -g @xata.io/cli` or via Bun)

**Note:** Commands support `--json` flag for machine-readable output. Use `--profile <name>` to switch between authenticated profiles.

## Emergency Quick Commands

### Check Current State

```bash
# Show current project, branch, and auth status
xata status

# List all branches in current project
xata branch list

# Get connection string for current branch
xata branch url
```

### Authentication

```bash
# Login (device flow)
xata auth login

# Check auth status
xata auth status

# Switch profile
xata auth switch <profile-name>
```

### Branch Operations

```bash
# Create a new branch
xata branch create <name> --region <region>

# Switch to another branch
xata branch checkout <name>

# Wait for branch to become healthy
xata branch wait-ready

# Delete a branch
xata branch delete <name> --force
```

### Schema Migrations

```bash
# Check migration status
xata roll status

# Apply migration (start + complete)
xata roll migrate <migration-file>

# Rollback if something went wrong
xata roll rollback
```

## Common Workflows

### Initial Project Setup

Copy this checklist and track progress:

```
- [ ] Login to Xata: xata auth login
- [ ] Initialize project: xata project init
- [ ] Verify setup: xata status
- [ ] Get connection string: xata branch url
```

**Details:** [reference/auth.md](reference/auth.md) | [reference/projects.md](reference/projects.md)

### Create a Feature Branch

Copy this checklist and track progress:

```
- [ ] Verify current branch: xata status
- [ ] Create new branch: xata branch create <name> --region <region>
- [ ] Wait for health: xata branch wait-ready
- [ ] Switch to branch: xata branch checkout <name>
- [ ] Get connection string: xata branch url
```

**Details:** [reference/branches.md](reference/branches.md)

### Schema Migration

Copy this checklist and track progress:

```
- [ ] Read reference/migrations.md
- [ ] Initialize migrations: xata roll init (if first time)
- [ ] Create migration file
- [ ] Start migration: xata roll start <file>
- [ ] Test changes
- [ ] Complete migration: xata roll complete
- [ ] If issues: xata roll rollback
```

**Details:** [reference/migrations.md](reference/migrations.md)

### Invite Team Members

Copy this checklist and track progress:

```
- [ ] List current organization: xata org list
- [ ] Invite member: xata org members invite <email>
- [ ] Verify: xata org members list
```

**Details:** [reference/organizations.md](reference/organizations.md)

### Clone Database with Anonymization

Copy this checklist and track progress:

```
- [ ] Read reference/clone.md
- [ ] Generate config: xata clone config (or --mode ai for AI assistance)
- [ ] Review and edit config file
- [ ] Start clone: xata clone start --source <src> --target <dst> --config <file>
- [ ] Validate: xata clone stream --validate
```

**Details:** [reference/clone.md](reference/clone.md)

## Key Commands Summary

| Category     | Commands                                                        |
| ------------ | --------------------------------------------------------------- |
| Auth         | `login`, `logout`, `status`, `switch`, `list`, `access-token`   |
| Project      | `init`, `list`, `describe`, `create`, `delete`, `backup`        |
| Branch       | `list`, `create`, `delete`, `checkout`, `url`, `wait-ready`     |
| Organization | `list`, `describe`, `create`, `members`, `invitations`          |
| Keys         | `user list/create/delete`, `org list/create/delete`             |
| Roll         | `init`, `start`, `status`, `complete`, `rollback`, `migrate`    |
| Clone        | `start`, `config`, `stream`                                     |
| Utility      | `status`, `version`, `upgrade`, `ai sql`                        |

## Output Formats

All commands output human-readable tables by default. Add `--json` for machine-readable output:

```bash
xata branch list --json | jq '.[] | .name'
```
