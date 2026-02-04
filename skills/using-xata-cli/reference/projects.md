# Projects

Create and manage Xata projects.

## Initialize Project

Link current directory to a Xata project:

```bash
xata project init
```

This creates local configuration files (`.xata/` directory) and prompts for organization and project selection.

With specific organization:

```bash
xata project init --organization <org-id>
```

Link to existing project:

```bash
xata project init --project <project-id>
```

**Aliases:** `connect`, `switch`, `link`

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

For specific project:

```bash
xata project describe --project <id>
```

**Aliases:** `view`, `show`

## Create Project

```bash
xata project create <name>
```

In specific organization:

```bash
xata project create <name> --organization <org-id>
```

## Delete Project

```bash
xata project delete
```

Skip confirmation:

```bash
xata project delete --force
```

Delete specific project:

```bash
xata project delete --project <id>
```

## Project Configuration

### Get Configuration

```bash
xata project get <key>
```

### Set Configuration

```bash
xata project set <key> <value>
```

## Backups

### List Backups

```bash
xata project backup list
```

### View Backup Details

```bash
xata project backup describe <backup-id>
```

### Configure Backups

```bash
xata project backup configure --enabled --retention-days 30
```

## Local Configuration Files

After `project init`, the CLI creates:

- `.xata/` - Project configuration directory
- Project and branch configuration files

These files are typically excluded from git via `.gitignore`.

## Check Current Project

```bash
xata status
```

Shows current project, branch, and authentication status.
