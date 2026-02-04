# Xata Skills

A collection of agent skills for AI coding assistants.

## Installation

```bash
npx skills add xataio/skills
```

For more information about skills, visit [skills.sh](https://skills.sh).

## Available Skills

| Skill                 | Reference                                                            | Description                   |
| --------------------- | -------------------------------------------------------------------- | ----------------------------- |
| `managing-postgresql` | [monitoring](skills/managing-postgresql/reference/monitoring.md)     | Health checks, metrics review |
| `managing-postgresql` | [slow-queries](skills/managing-postgresql/reference/slow-queries.md) | Query analysis, EXPLAIN plans |
| `managing-postgresql` | [high-cpu](skills/managing-postgresql/reference/high-cpu.md)         | CPU investigation             |
| `managing-postgresql` | [memory](skills/managing-postgresql/reference/memory.md)             | Memory pressure, OOM          |
| `managing-postgresql` | [connections](skills/managing-postgresql/reference/connections.md)   | Connection management         |
| `managing-postgresql` | [locks](skills/managing-postgresql/reference/locks.md)               | Locks and deadlocks           |
| `managing-postgresql` | [disk-space](skills/managing-postgresql/reference/disk-space.md)     | Storage management            |
| `managing-postgresql` | [vacuum](skills/managing-postgresql/reference/vacuum.md)             | Vacuum, autovacuum, bloat     |
| `managing-postgresql` | [indexes](skills/managing-postgresql/reference/indexes.md)           | Index optimization            |
| `managing-postgresql` | [tuning](skills/managing-postgresql/reference/tuning.md)             | Configuration tuning          |
| `managing-postgresql` | [backup](skills/managing-postgresql/reference/backup.md)             | Backup and recovery           |
| `managing-postgresql` | [replication](skills/managing-postgresql/reference/replication.md)   | Replication, failover         |
| `managing-postgresql` | [security](skills/managing-postgresql/reference/security.md)         | Access control, permissions   |
| `using-xata-cli`      | [auth](skills/using-xata-cli/reference/auth.md)                      | Login, profiles, tokens       |
| `using-xata-cli`      | [projects](skills/using-xata-cli/reference/projects.md)              | Project setup, configuration  |
| `using-xata-cli`      | [branches](skills/using-xata-cli/reference/branches.md)              | Branch management, URLs       |
| `using-xata-cli`      | [migrations](skills/using-xata-cli/reference/migrations.md)          | Schema migrations (pgroll)    |
| `using-xata-cli`      | [organizations](skills/using-xata-cli/reference/organizations.md)    | Team and org management       |
| `using-xata-cli`      | [keys](skills/using-xata-cli/reference/keys.md)                      | API key management            |
| `using-xata-cli`      | [clone](skills/using-xata-cli/reference/clone.md)                    | Database cloning              |

## Contributing

When adding new skills:

1. Create a new directory under `skills/` with a descriptive name (prefer gerund form, e.g., `managing-postgresql`)
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`)
3. Keep SKILL.md under 500 lines - use `reference/` subdirectory for detailed content
4. Follow progressive disclosure: SKILL.md provides overview, reference files provide depth
5. Include practical examples and concise explanations (Claude already knows the basics)
