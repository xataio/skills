---
name: using-xata-cli
description: Manages Xata serverless PostgreSQL databases via the xata CLI. Triggers when working with Xata projects, branches, organizations, authentication, schema migrations (pgroll), data cloning, scratch (on-demand fast) branches, branch metrics, or AI-powered SQL generation. Handles xata commands, database branch management, project setup, team management, connection strings, and database administration tasks.
---

# Using Xata CLI

## Quick Reference

**What do you need to do?**

| Task                                  | Reference                                                |
| ------------------------------------- | -------------------------------------------------------- |
| Login, switch profiles, manage tokens | [reference/auth.md](reference/auth.md)                   |
| Create, configure, or link projects   | [reference/projects.md](reference/projects.md)           |
| Create, checkout, or delete branches  | [reference/branches.md](reference/branches.md)           |
| Schema migrations with pgroll         | [reference/migrations.md](reference/migrations.md)       |
| Manage organizations and team members | [reference/organizations.md](reference/organizations.md) |
| Create or manage API keys             | [reference/keys.md](reference/keys.md)                   |
| Clone databases with anonymization    | [reference/clone.md](reference/clone.md)                 |

## Prerequisites

**Required:** Xata CLI installed

```bash
# Install via npm
npm install -g @xata.io/cli

# Verify installation (also prints pgroll and pgstream versions)
xata version
```

**Notes:**

- Most read commands support a `--json` flag for machine-readable output.
- The active profile is selected with `xata auth switch`; the `--profile <name>` flag is only available on `xata auth` commands. For other commands, set the active profile first or export `XATA_API_KEY`.
- Many commands accept `--organization <id>`, `--project <id>`, `--branch <id>`, and `--database <name>` to override the values stored in the local `.xata` config.

## Emergency Quick Commands

### Check Current State

```bash
# Show current profile, organization, project, and branch
xata status

# List all branches in current project
xata branch list

# Get connection string for current branch
xata branch url
```

### Authentication

```bash
# Login (device flow, opens browser)
xata auth login

# Check active account and auth state
xata auth status

# Switch the active profile
xata auth switch <profile-name>
```

### Branch Operations

```bash
# Create a new branch (interactive prompts fill in missing options)
xata branch create --name <name> --region <region>

# Switch the local working branch (also: xata checkout <name>)
xata branch checkout <name>

# Wait for a branch to become ready
xata branch wait-ready <name>

# Delete a branch (skip the prompt with --yes)
xata branch delete <name> --yes
```

### Schema Migrations

```bash
# Check migration status
xata roll status

# Apply all migrations in a folder, start + complete in one step
xata roll migrate ./migrations --complete

# Roll back the active (incomplete) migration
xata roll rollback
```

## Common Workflows

### Initial Project Setup

Copy this checklist and track progress:

```
- [ ] Login to Xata: xata auth login
- [ ] Link the folder to a project: xata init   (alias of: xata project init)
- [ ] Verify setup: xata status
- [ ] Get connection string: xata branch url
```

`xata onboard` is also available to create an org, project, and branch in one guided flow for a brand-new account.

**Details:** [reference/auth.md](reference/auth.md) | [reference/projects.md](reference/projects.md)

### Create a Feature Branch

Copy this checklist and track progress:

```
- [ ] Verify current branch: xata status
- [ ] Create new branch: xata branch create --name <name> --parent-branch main
- [ ] Wait until ready: xata branch wait-ready <name>
- [ ] Switch to branch: xata branch checkout <name>
- [ ] Get connection string: xata branch url
```

**If wait-ready hangs:** check branch state with `xata branch describe <name>` and verify the region/instance type are valid. If the branch is hibernated, `xata branch wait-ready <name> --wake` wakes it up.

**Details:** [reference/branches.md](reference/branches.md)

### Schema Migration

Copy this checklist and track progress:

```
- [ ] Read reference/migrations.md
- [ ] Initialize migrations (first time only): xata roll init
- [ ] Create a pgroll migration file in the migrations folder
- [ ] Start migration: xata roll start <file>
- [ ] Test the new schema version against your app
- [ ] Complete migration: xata roll complete
- [ ] If issues: xata roll rollback
```

**If migration fails:** check `xata roll status` for details. Roll back the in-progress migration with `xata roll rollback` before retrying.

**Details:** [reference/migrations.md](reference/migrations.md)

### Invite Team Members

Copy this checklist and track progress:

```
- [ ] Confirm the organization: xata org list
- [ ] Invite member: xata org members invite --email <email>
- [ ] Verify: xata org members list
```

**Details:** [reference/organizations.md](reference/organizations.md)

### Clone Database with Anonymization

Copy this checklist and track progress:

```
- [ ] Read reference/clone.md
- [ ] Generate transform config: xata clone config --source-url <url> (use --mode ai for AI assistance)
- [ ] Review the generated transforms in the project config
- [ ] Run the clone into the current branch: xata clone start --source-url <url>
```

`xata clone start` clones into the branch configured for the current project (or the one passed with `--branch`); there is no separate target flag.

**Details:** [reference/clone.md](reference/clone.md)

### Run Throwaway SQL on a Scratch Branch

`xata scratch` spins up a temporary on-demand "fast" branch from your current branch, runs your command against it, and deletes it on exit. Useful for one-off queries or running a Postgres client without touching a long-lived branch.

```bash
# Run a single query
xata scratch --execute "select count(*) from users"

# Open a psql session against a fresh scratch branch
xata scratch psql
```

The scratch branch exposes `DATABASE_URL`, `XATA_DATABASE_URL`, and the standard `PG*` environment variables to the spawned command.

## Output Formats

Most read commands output human-readable tables by default. Add `--json` for machine-readable output:

```bash
xata branch list --json | jq '.[] | .name'
```

## Common Issues

**"You are logged out":** Run `xata auth login`.

**"Project not found" / no project linked:** Run `xata init` (alias of `xata project init`) or check `xata status`.

**"Branch not found":** Verify the branch name with `xata branch list` (names are case-sensitive).

**Command hangs:** Check network connectivity; try `xata status` first.

**Wrong organization/project:** Pass `--organization`, `--project`, or `--branch` to override the linked values, or re-run `xata init`. To use a different account, switch the active profile with `xata auth switch`.
