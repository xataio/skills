# Xata Skills

A collection of agent skills for AI coding assistants.

## Installation

Install all skills:

```bash
npx skills add xataio/skills
```

For more information about skills, visit [skills.sh](https://skills.sh).

## Available Skills

### managing-postgresql

Diagnoses and troubleshoots PostgreSQL database issues including slow queries, high CPU, memory pressure, connections, locks, vacuum, indexes, and replication.

```bash
npx skills add xataio/skills/skills/managing-postgresql
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
npx skills add xataio/skills/skills/using-xata-cli
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

## Contributing

When adding new skills:

1. Create a new directory under `skills/` with a descriptive name (prefer gerund form, e.g., `managing-postgresql`)
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`)
3. Keep SKILL.md under 500 lines - use `reference/` subdirectory for detailed content
4. Follow progressive disclosure: SKILL.md provides overview, reference files provide depth
5. Include practical examples and concise explanations (Claude already knows the basics)
