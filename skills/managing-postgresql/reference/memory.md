# Memory Investigation

## Contents

- [Check Memory Configuration](#check-memory-configuration)
- [Memory Guidelines](#memory-guidelines)
- [Check Active Connections](#check-active-connections)
- [Find Memory-Heavy Queries](#find-memory-heavy-queries-pg_stat_statements)
- [Immediate Actions](#immediate-actions)
- [Common Issues](#common-issues)
- [PgBouncer Example](#pgbouncer-example)

## Check Memory Configuration

```sql
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem',
               'effective_cache_size', 'max_connections');
```

## Memory Guidelines

| Setting                | Recommendation                                 | Notes                    |
| ---------------------- | ---------------------------------------------- | ------------------------ |
| `shared_buffers`       | 25% of RAM (max ~8GB)                          | Main buffer cache        |
| `work_mem`             | (RAM - shared_buffers) / (max_connections × 3) | Per-operation            |
| `maintenance_work_mem` | 5% of RAM (max 1-2GB)                          | For VACUUM, CREATE INDEX |
| `effective_cache_size` | ~75% of RAM                                    | Query planner hint only  |
| `huge_pages`           | `try` for shared_buffers >= 8GB                | Reduces overhead         |

**Example for 32GB RAM:**

```
shared_buffers = 8GB
work_mem = 80MB
maintenance_work_mem = 1.6GB
effective_cache_size = 24GB
```

## Check Active Connections

```sql
SELECT count(*) AS total,
       count(*) FILTER (WHERE state = 'active') AS active,
       count(*) FILTER (WHERE state = 'idle') AS idle,
       count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_txn
FROM pg_stat_activity;
```

## Find Memory-Heavy Queries (pg_stat_statements)

```sql
SELECT query, calls, temp_blks_written,
       pg_size_pretty(temp_blks_written * 8192) AS temp_written
FROM pg_stat_statements
WHERE temp_blks_written > 0
ORDER BY temp_blks_written DESC LIMIT 10;
```

## Immediate Actions

### Terminate Memory-Heavy Queries

```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'active' AND query_start < NOW() - INTERVAL '1 hour';
```

### Reduce work_mem

```sql
ALTER SYSTEM SET work_mem = '32MB';
SELECT pg_reload_conf();
```

## Common Issues

| Issue                    | Symptoms                            | Solution                                  |
| ------------------------ | ----------------------------------- | ----------------------------------------- |
| Too many connections     | Memory scales with connection count | Use connection pooler (PgBouncer)         |
| shared_buffers too high  | System swapping                     | Reduce to 25% of RAM or 8GB max           |
| Memory-intensive queries | Large sorts, temp files             | Reduce work_mem, optimize queries         |
| Connection leaks         | Connections grow over time          | Fix application, set idle_session_timeout |

## PgBouncer Example

```ini
[databases]
mydb = host=<DB_HOST> dbname=mydb

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
```
