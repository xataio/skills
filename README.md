# Xata Skills

A collection of agent skills for AI coding assistants.

## Installation

```bash
npx skills add xataio/skills
```

For more information about skills, visit [skills.sh](https://skills.sh).

## Available Skills

### PostgreSQL DBA

Skills for PostgreSQL database administration and troubleshooting.

| Skill                              | Description                                               |
| ---------------------------------- | --------------------------------------------------------- |
| `monitoring-pg-health`             | Database health monitoring, metrics review, log analysis  |
| `investigating-pg-slow-queries`    | Slow query analysis, EXPLAIN plans, index recommendations |
| `investigating-pg-high-cpu`        | CPU usage diagnosis, active queries, lock detection       |
| `investigating-pg-memory`          | Memory pressure diagnosis, OOM analysis, configuration    |
| `investigating-pg-connections`     | Connection management, idle connections, pooling          |
| `tuning-pg-performance`            | Configuration optimization, parameter recommendations     |
| `maintaining-pg-vacuum`            | Vacuum operations, dead tuples, autovacuum management     |
| `investigating-pg-locks-deadlocks` | Lock detection, blocking queries, deadlock resolution     |

## Contributing

When adding new skills:

1. Create a new directory under `skills/` with a descriptive name using gerund form (e.g., `investigating-*`, `monitoring-*`)
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`)
3. Include a Prerequisites section documenting required dependencies
4. Add reference files in a `references/` subdirectory if needed (use Markdown format)
5. Include practical examples and interpretation guides
