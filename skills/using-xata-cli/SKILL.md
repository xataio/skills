---
name: using-xata-cli
description: Manages Xata serverless PostgreSQL databases via the xata CLI. Triggers when working with Xata projects, branches, organizations, authentication, schema migrations (pgroll), data cloning, or AI-powered SQL generation. Handles xata commands, database branch management, project setup, team management, connection strings, and database administration tasks.
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

**Required:** Xata CLI installed

```bash
# Install via npm
npm install -g @xata.io/cli

# Verify installation
xata version
```

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
- [ ] Wait for health: xata branch wait-ready --timeout 300
- [ ] Switch to branch: xata branch checkout <name>
- [ ] Get connection string: xata branch url
```

**If wait-ready times out:** Check branch status with `xata branch describe --branch <name>` and verify the region is valid.

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

**If migration fails:** Check `xata roll status` for error details. Rollback with `xata roll rollback` before retrying.

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

**If clone fails:** Check config file for excluded tables. Validate with `xata clone stream --validate` for detailed errors.

**Details:** [reference/clone.md](reference/clone.md)

## Output Formats

All commands output human-readable tables by default. Add `--json` for machine-readable output:

```bash
xata branch list --json | jq '.[] | .name'
```

## Common Issues

**"Not authenticated":** Run `xata auth login`

**"Project not found":** Run `xata project init` or check `xata status`

**"Branch not found":** Verify branch name with `xata branch list`

**Command hangs:** Check network connectivity; try `xata status` first

**Wrong organization/project:** Use `--profile`, `--organization`, or `--project` flags to override defaults
