# Xata Skills

A collection of agent skills for AI coding assistants, packaged as an [Agent Plugin](https://agent-plugins.org/).

A client that implements the standard loads it from a clone of this repository:

```text
plugin.json    # manifest
mcp.json       # hosted Xata MCP server
skills/        # one directory per skill, each with a SKILL.md
```

## MCP server

The plugin declares Xata's hosted MCP server at `https://api.xata.tech/mcp`, adding typed tools for organizations, projects, branches, and SQL. It is remote (nothing to install) and speaks Streamable HTTP only.

Authentication is handled by your client — no credentials are committed here. Most clients run the browser OAuth flow on first connection. For headless use, add the server with an API key directly instead:

```bash
claude mcp add --transport http xata https://api.xata.tech/mcp \
  --header "Authorization: Bearer $XATA_API_KEY"
```

See the [Xata MCP documentation](https://xata.io/docs/platform/mcp) for per-client setup.

## Installation

Install all skills:

```bash
npx skills add xataio/skills
```

Install a specific skill:

```bash
npx skills add xataio/skills --skill managing-postgresql
```

For more information about skills, visit [skills.sh](https://skills.sh).

## Available Skills

### managing-postgresql

Diagnoses and troubleshoots PostgreSQL database issues including slow queries, high CPU, memory pressure, connections, locks, vacuum, indexes, and replication.

```bash
npx skills add xataio/skills --skill managing-postgresql
```

| Reference                                                            | Description                   |
| -------------------------------------------------------------------- | ----------------------------- |
| [monitoring](skills/managing-postgresql/reference/monitoring.md)     | Health checks, metrics review |
| [slow-queries](skills/managing-postgresql/reference/slow-queries.md) | Query analysis, EXPLAIN plans |
| [high-cpu](skills/managing-postgresql/reference/high-cpu.md)         | CPU investigation             |
| [memory](skills/managing-postgresql/reference/memory.md)             | Memory pressure, OOM          |
| [connections](skills/managing-postgresql/reference/connections.md)   | Connection management         |
| [locks](skills/managing-postgresql/reference/locks.md)               | Locks and deadlocks           |
| [disk-space](skills/managing-postgresql/reference/disk-space.md)     | Storage management            |
| [vacuum](skills/managing-postgresql/reference/vacuum.md)             | Vacuum, autovacuum, bloat     |
| [indexes](skills/managing-postgresql/reference/indexes.md)           | Index optimization            |
| [tuning](skills/managing-postgresql/reference/tuning.md)             | Configuration tuning          |
| [backup](skills/managing-postgresql/reference/backup.md)             | Backup and recovery           |
| [replication](skills/managing-postgresql/reference/replication.md)   | Replication, failover         |
| [security](skills/managing-postgresql/reference/security.md)         | Access control, permissions   |

### using-xata-cli

Manages Xata serverless PostgreSQL databases via the xata CLI. Covers authentication, projects, branches, schema migrations (pgroll), organizations, API keys, and database cloning with anonymization.

```bash
npx skills add xataio/skills --skill using-xata-cli
```

| Reference                                                         | Description                  |
| ----------------------------------------------------------------- | ---------------------------- |
| [auth](skills/using-xata-cli/reference/auth.md)                   | Login, profiles, tokens      |
| [projects](skills/using-xata-cli/reference/projects.md)           | Project setup, configuration |
| [branches](skills/using-xata-cli/reference/branches.md)           | Branch management, URLs      |
| [migrations](skills/using-xata-cli/reference/migrations.md)       | Schema migrations (pgroll)   |
| [organizations](skills/using-xata-cli/reference/organizations.md) | Team and org management      |
| [keys](skills/using-xata-cli/reference/keys.md)                   | API key management           |
| [clone](skills/using-xata-cli/reference/clone.md)                 | Database cloning             |

### using-xata-api

Uses the Xata HTTP API to manage organizations, projects, and branches, authenticate with an API key or OAuth, get a branch connection string, and understand pagination and error conventions.

```bash
npx skills add xataio/skills --skill using-xata-api
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on creating and maintaining skills.
