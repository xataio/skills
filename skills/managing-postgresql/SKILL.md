---
name: managing-postgresql
description: PostgreSQL database administration and troubleshooting. Use for any PostgreSQL issue including slow queries, high CPU, memory pressure, connection problems, locks, deadlocks, disk space, vacuum, autovacuum, table bloat, index optimization, performance tuning, backup, recovery, pg_dump, replication, replication lag, failover, security, permissions, pg_hba.conf, or general database health monitoring.
---

# Managing PostgreSQL

## Quick Diagnosis

**What's the issue?**

| Symptom                                 | Reference                                              |
| --------------------------------------- | ------------------------------------------------------ |
| Database slow, queries taking too long  | [reference/slow-queries.md](reference/slow-queries.md) |
| High CPU usage                          | [reference/high-cpu.md](reference/high-cpu.md)         |
| Low memory, OOM errors                  | [reference/memory.md](reference/memory.md)             |
| Too many connections, connection errors | [reference/connections.md](reference/connections.md)   |
| Queries blocked, deadlocks              | [reference/locks.md](reference/locks.md)               |
| Disk space running low                  | [reference/disk-space.md](reference/disk-space.md)     |
| Table bloat, dead tuples                | [reference/vacuum.md](reference/vacuum.md)             |
| Index issues, missing indexes           | [reference/indexes.md](reference/indexes.md)           |
| Need to tune configuration              | [reference/tuning.md](reference/tuning.md)             |
| Backup or recovery needed               | [reference/backup.md](reference/backup.md)             |
| Replication lag, failover               | [reference/replication.md](reference/replication.md)   |
| Security, permissions, access           | [reference/security.md](reference/security.md)         |
| General health check                    | [reference/monitoring.md](reference/monitoring.md)     |

## Prerequisites

**Required PostgreSQL version:** 9.6+ (specific features may require newer versions as noted)

**Recommended extensions:**

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- Query analysis
CREATE EXTENSION IF NOT EXISTS pgstattuple;          -- Bloat measurement
```

**Note:** SQL queries can be run remotely via any PostgreSQL client. Shell commands require server filesystem access or cloud provider tools.

## Emergency Quick Commands

### Check What's Happening Now

```sql
-- Active queries (what's running?)
SELECT pid, state, NOW() - query_start AS duration, LEFT(query, 80) AS query
FROM pg_stat_activity
WHERE state != 'idle' AND pid != pg_backend_pid()
ORDER BY duration DESC;

-- Blocked queries (who's waiting?)
SELECT pid, wait_event_type, wait_event, LEFT(query, 60) AS query
FROM pg_stat_activity
WHERE wait_event_type = 'Lock';

-- Connection count
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
```

### Kill a Problem Query

```sql
-- Cancel query (soft)
SELECT pg_cancel_backend(<pid>);

-- Terminate connection (hard)
SELECT pg_terminate_backend(<pid>);
```

### Check Resource Usage

```sql
-- Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database ORDER BY pg_database_size(datname) DESC;

-- Largest tables
SELECT schemaname || '.' || relname AS table,
       pg_size_pretty(pg_total_relation_size(relid)) AS size,
       n_dead_tup AS dead_tuples
FROM pg_stat_user_tables ORDER BY pg_total_relation_size(relid) DESC LIMIT 10;

-- Connection utilization
SELECT count(*) AS current, current_setting('max_connections') AS max,
       round(100.0 * count(*) / current_setting('max_connections')::int, 1) AS pct
FROM pg_stat_activity;
```

## Common Workflows

### Slow Query Investigation

Copy this checklist and track progress:

```
- [ ] Read reference/slow-queries.md
- [ ] Identify slow queries using pg_stat_statements
- [ ] Run EXPLAIN ANALYZE on problematic queries
- [ ] Check for missing indexes (reference/indexes.md)
- [ ] Check for stale statistics (run ANALYZE)
```

**Details:** [reference/slow-queries.md](reference/slow-queries.md) | [reference/indexes.md](reference/indexes.md)

### High CPU Investigation

Copy this checklist and track progress:

```
- [ ] Read reference/high-cpu.md
- [ ] Check active queries for long-running operations
- [ ] Check for lock contention (reference/locks.md)
- [ ] Check vacuum status (reference/vacuum.md)
- [ ] Review slow queries (reference/slow-queries.md)
```

**Details:** [reference/high-cpu.md](reference/high-cpu.md) | [reference/locks.md](reference/locks.md) | [reference/vacuum.md](reference/vacuum.md)

### Disk Space Emergency

Copy this checklist and track progress:

```
- [ ] Read reference/disk-space.md
- [ ] Identify largest tables and indexes
- [ ] Check for WAL accumulation (replication slots)
- [ ] Check for bloat (reference/vacuum.md)
- [ ] Consider dropping unused indexes (reference/indexes.md)
```

**Details:** [reference/disk-space.md](reference/disk-space.md) | [reference/vacuum.md](reference/vacuum.md) | [reference/indexes.md](reference/indexes.md)

### Connection Exhaustion

Copy this checklist and track progress:

```
- [ ] Read reference/connections.md
- [ ] Check connection states and sources
- [ ] Kill idle-in-transaction connections if needed
- [ ] Consider connection pooling (PgBouncer)
```

**Details:** [reference/connections.md](reference/connections.md)

### Database Maintenance

Copy this checklist and track progress:

```
- [ ] Vacuum bloated tables (reference/vacuum.md)
- [ ] Reindex bloated indexes (reference/indexes.md)
- [ ] Update statistics: ANALYZE
- [ ] Review autovacuum settings
```

**Details:** [reference/vacuum.md](reference/vacuum.md) | [reference/indexes.md](reference/indexes.md)

### Backup & Recovery

Copy this checklist and track progress:

```
- [ ] Read reference/backup.md
- [ ] Use pg_dump for logical backups
- [ ] Use pg_basebackup for physical backups
- [ ] Configure WAL archiving for PITR
```

**Details:** [reference/backup.md](reference/backup.md)

### Replication Issues

Copy this checklist and track progress:

```
- [ ] Read reference/replication.md
- [ ] Check replication lag on primary
- [ ] Review replication slot status
- [ ] Check for WAL accumulation
```

**Details:** [reference/replication.md](reference/replication.md)

## Key System Views

| View                   | Purpose                                 |
| ---------------------- | --------------------------------------- |
| `pg_stat_activity`     | Current connections and queries         |
| `pg_stat_user_tables`  | Table statistics, dead tuples           |
| `pg_stat_user_indexes` | Index usage statistics                  |
| `pg_stat_statements`   | Historical query statistics (extension) |
| `pg_locks`             | Current lock information                |
| `pg_stat_replication`  | Replication status (primary)            |
| `pg_stat_wal_receiver` | Replication status (replica)            |
| `pg_replication_slots` | Replication slot status                 |
| `pg_settings`          | Configuration parameters                |

## Investigation Summary Template

After investigating any issue, provide a summary:

```
## Investigation Summary

**Issue Type:** [Slow queries / High CPU / Memory / Connections / Locks / Disk / etc.]
**Severity:** [Critical / Warning / Informational]

**Root Cause:**
[What caused the issue]

**Actions Taken:**
- [Action 1]
- [Action 2]

**Recommendations:**
1. [Short-term fix]
2. [Long-term improvement]

**Monitoring:**
[What to watch for]
```
