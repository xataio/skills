# Projects

Create and manage Xata projects.

## Contents

- [Initialize / Link Project](#initialize--link-project)
- [List Projects](#list-projects)
- [View Project Details](#view-project-details)
- [Create Project](#create-project)
- [Delete Project](#delete-project)
- [Project Configuration](#project-configuration)
- [IP Filtering](#ip-filtering)
- [Backups](#backups)
- [Local Configuration Files](#local-configuration-files)
- [Common Issues](#common-issues)

## Initialize / Link Project

Link the current folder to a Xata project:

```bash
xata project init
```

`xata init` is a top-level shortcut for the same command.

This writes the local `.xata` configuration and prompts for organization, project, branch, and database when not provided. You can pass `--branch <id>` and `--database <name>` to preset them.

**Aliases:** `connect`, `switch`, `link` (so `xata project link` and `xata project switch` also run init).

## List Projects

```bash
xata project list
```

Filter by organization:

```bash
xata project list --organization <org-id>
```

JSON output:

```bash
xata project list --json
```

## View Project Details

```bash
xata project describe
```

For a specific project (positional or `--project`):

```bash
xata project describe <name>
xata project describe --project <id>
```

**Aliases:** `view`, `show`

## Create Project

```bash
xata project create
```

The command prompts for the project name, branch name, region, instance type, replicas, PostgreSQL version, and scale-to-zero defaults. You can pre-fill them with flags such as `--name`, `--branch-name`, `--region`, `--instance-type`, `--replicas`, `--postgres-version`, `--scale-to-zero-base`, `--scale-to-zero-child`, `--inactivity-period-base`, and `--inactivity-period-child`. Use `--organization <org-id>` to target a specific organization.

## Delete Project

```bash
xata project delete
```

Skip confirmation:

```bash
xata project delete --yes
```

Delete a specific project:

```bash
xata project delete --project <id>
```

## Project Configuration

`xata project get` / `xata project set` read and write project fields.

### Get a Field

```bash
xata project get <field>
```

### Set a Field

```bash
xata project set <field> <value>
```

## IP Filtering

Manage allowed IP ranges for a project. Running `xata project ip-filter` with no subcommand lists the current rules.

```bash
# List rules
xata project ip-filter list

# Add / remove a rule
xata project ip-filter add <cidr>
xata project ip-filter remove <cidr>

# Enable / disable filtering
xata project ip-filter enable
xata project ip-filter disable
```

## Backups

Point-in-time recovery (PITR) backups are configured per branch.

### Show Backup Information for a Branch

```bash
xata project backup list --branch <branch-id>
```

**Alias:** `ls`

### Describe a Specific Backup

```bash
xata project backup describe --backup <backup-id>
```

**Alias:** `get`

### Configure the Backup Schedule

```bash
xata project backup configure <branch-name> \
  --retention <2-40> \
  --cadence <daily|weekly> \
  --day-of-week <monday|tuesday|...> \
  --time <HH:MM>
```

`--day-of-week` only applies when `--cadence weekly`. `--time` is in 24-hour `HH:MM` format.

## Local Configuration Files

After `project init`, the CLI writes a `.xata` configuration in the folder holding the organization, project, branch, and database selection. These files are typically excluded from git via `.gitignore`.

## Check Current Project

```bash
xata status
```

Shows the active profile, organization, project, and branch.

## Common Issues

**"Project not found":** Run `xata init` to link a project. Verify the ID with `xata project list`.

**"You are logged out":** Run `xata auth login` before project operations.

**Wrong project context:** Pass `--project <id>` or re-run `xata init`.

**Cannot delete project:** Ensure all branches are deleted first. Use `--yes` to skip confirmation.

**Init wrote the wrong config:** Delete the local `.xata` config and run `xata init` again with explicit `--project`.
