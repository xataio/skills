# Xata Skills

A collection of agent skills for AI coding assistants.

## Installation

```bash
npx skills add xataio/skills
```

For more information about skills, visit [skills.sh](https://skills.sh).

## Available Skills

### PostgreSQL DBA

Complete PostgreSQL database administration skill with progressive disclosure.

| Skill            | Description                                                                                                                                                                              |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `postgresql-dba` | Full PostgreSQL DBA toolkit: monitoring, slow queries, high CPU, memory, connections, locks, disk space, vacuum, indexes, performance tuning, backup/recovery, replication, and security |

**Topics covered:**

| Reference                                                          | Use Case                      |
| ------------------------------------------------------------------ | ----------------------------- |
| [monitoring.md](skills/postgresql-dba/reference/monitoring.md)     | Health checks, metrics review |
| [slow-queries.md](skills/postgresql-dba/reference/slow-queries.md) | Query analysis, EXPLAIN plans |
| [high-cpu.md](skills/postgresql-dba/reference/high-cpu.md)         | CPU investigation             |
| [memory.md](skills/postgresql-dba/reference/memory.md)             | Memory pressure, OOM          |
| [connections.md](skills/postgresql-dba/reference/connections.md)   | Connection management         |
| [locks.md](skills/postgresql-dba/reference/locks.md)               | Locks and deadlocks           |
| [disk-space.md](skills/postgresql-dba/reference/disk-space.md)     | Storage management            |
| [vacuum.md](skills/postgresql-dba/reference/vacuum.md)             | Vacuum, autovacuum, bloat     |
| [indexes.md](skills/postgresql-dba/reference/indexes.md)           | Index optimization            |
| [tuning.md](skills/postgresql-dba/reference/tuning.md)             | Configuration tuning          |
| [backup.md](skills/postgresql-dba/reference/backup.md)             | Backup and recovery           |
| [replication.md](skills/postgresql-dba/reference/replication.md)   | Replication, failover         |
| [security.md](skills/postgresql-dba/reference/security.md)         | Access control, permissions   |

## Contributing

When adding new skills:

1. Create a new directory under `skills/` with a descriptive name
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`)
3. Keep SKILL.md under 500 lines - use `reference/` subdirectory for detailed content
4. Follow progressive disclosure: SKILL.md provides overview, reference files provide depth
5. Include practical examples and concise explanations (Claude already knows the basics)
