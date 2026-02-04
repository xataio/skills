# PostgreSQL General Monitoring Queries

Reference collection for database health assessment.

## Table of Contents

- [Connection Statistics](#connection-statistics)
- [Slow Query Analysis](#slow-query-analysis) (requires pg_stat_statements)
- [Table Statistics](#table-statistics)
- [Index Statistics](#index-statistics)
- [Configuration Settings](#configuration-settings)
- [Database Health Overview](#database-health-overview)

---

## Connection Statistics

Monitor connection utilization and identify potential connection exhaustion.

### Connection Utilization Overview

```sql
SELECT
    A.total_connections,
    A.non_idle_connections,
    B.max_connections,
    round((100 * A.total_connections::numeric / B.max_connections::numeric), 2) AS connections_utilization_pctg
FROM
    (SELECT count(1) AS total_connections,
            sum(CASE WHEN state != 'idle' THEN 1 ELSE 0 END) AS non_idle_connections
     FROM pg_stat_activity) A,
    (SELECT setting AS max_connections FROM pg_settings WHERE name = 'max_connections') B;
```

#### Interpretation Guide

- **connections_utilization_pctg > 80%**: Warning - approaching connection limit
- **non_idle_connections**: Active work happening; high values indicate busy database

### Connection Breakdown by State

```sql
SELECT
    state,
    count(*) AS connection_count,
    round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS percentage
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY state
ORDER BY connection_count DESC;
```

#### Interpretation Guide

- **idle**: Connections waiting for work
- **active**: Currently executing queries
- **idle in transaction**: Holding transaction open (potentially problematic)

### Connections by Application

```sql
SELECT
    application_name,
    count(*) AS connections,
    sum(CASE WHEN state = 'active' THEN 1 ELSE 0 END) AS active,
    sum(CASE WHEN state = 'idle' THEN 1 ELSE 0 END) AS idle
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY application_name
ORDER BY connections DESC;
```

#### Interpretation Guide

- Identifies which applications consume the most connections
- High idle counts from one app may indicate connection pooling issues

---

## Slow Query Analysis

Requires `pg_stat_statements` extension.

### Top Queries by Total Execution Time

```sql
SELECT
    calls,
    round(max_exec_time/1000) AS max_exec_secs,
    round(mean_exec_time/1000) AS mean_exec_secs,
    round(total_exec_time/1000) AS total_exec_secs,
    query,
    queryid::text AS queryid
FROM pg_stat_statements
WHERE max_exec_time > 2000
ORDER BY total_exec_time DESC
LIMIT 10;
```

#### Interpretation Guide

- **total_exec_secs**: Cumulative time; highest impact queries
- **max_exec_secs > 2**: Queries with slow outliers
- **calls**: Frequency; optimize high-call queries first

### Top Queries by Mean Execution Time

```sql
SELECT
    calls,
    round(mean_exec_time::numeric, 2) AS mean_exec_ms,
    round(total_exec_time::numeric, 2) AS total_exec_ms,
    round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 2) AS pct_total_time,
    query
FROM pg_stat_statements
WHERE calls > 10
ORDER BY mean_exec_time DESC
LIMIT 10;
```

#### Interpretation Guide

- **mean_exec_ms**: Average time per call
- **pct_total_time**: Share of total database work

### Queries with High Buffer Usage

Identifies queries causing memory pressure.

```sql
SELECT
    calls,
    round(shared_blks_hit::numeric / NULLIF(shared_blks_hit + shared_blks_read, 0) * 100, 2) AS cache_hit_pct,
    shared_blks_read,
    shared_blks_hit,
    query
FROM pg_stat_statements
WHERE calls > 100
ORDER BY shared_blks_read DESC
LIMIT 10;
```

#### Interpretation Guide

- **cache_hit_pct < 90%**: Query reading heavily from disk
- **shared_blks_read**: High values indicate I/O-heavy queries

---

## Table Statistics

Size, row counts, and access patterns.

### Table Sizes with Access Statistics

```sql
SELECT
    t.table_name AS name,
    t.table_schema AS schema,
    pg_size_pretty(pg_total_relation_size(quote_ident(t.table_schema) || '.' || quote_ident(t.table_name))) AS size,
    ROUND(c.reltuples) AS rows,
    s.seq_scan,
    s.idx_scan
FROM information_schema.tables t
LEFT JOIN pg_class c ON t.table_name = c.relname
LEFT JOIN pg_stat_all_tables s ON c.oid = s.relid
WHERE t.table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(quote_ident(t.table_schema) || '.' || quote_ident(t.table_name)) DESC
LIMIT 20;
```

#### Interpretation Guide

- **seq_scan >> idx_scan**: Table may need better indexes
- **size**: Largest tables often need most attention

### Tables with High Sequential Scan Ratio

Candidates for indexing.

```sql
SELECT
    schemaname,
    relname AS table_name,
    seq_scan,
    idx_scan,
    CASE
        WHEN idx_scan = 0 THEN 100
        ELSE round(100.0 * seq_scan / (seq_scan + idx_scan), 2)
    END AS seq_scan_pct,
    n_live_tup AS estimated_rows
FROM pg_stat_user_tables
WHERE seq_scan > 0
    AND n_live_tup > 1000
ORDER BY seq_scan_pct DESC, seq_scan DESC
LIMIT 20;
```

#### Interpretation Guide

- **seq_scan_pct > 50%** on large tables: Consider adding indexes
- **estimated_rows > 10000** with high seq_scan: Priority for optimization

### Table Bloat Estimate

```sql
SELECT
    schemaname,
    relname AS table_name,
    n_dead_tup,
    n_live_tup,
    CASE
        WHEN n_live_tup = 0 THEN 0
        ELSE round(100.0 * n_dead_tup / n_live_tup, 2)
    END AS dead_tuple_pct,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 20;
```

#### Interpretation Guide

- **dead_tuple_pct > 10%**: Table needs vacuum
- **last_vacuum/last_autovacuum = NULL**: Vacuum may not be running

---

## Index Statistics

Index usage and health.

### Unused Indexes

Candidates for removal.

```sql
SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelid NOT IN (SELECT conindid FROM pg_constraint)
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;
```

#### Interpretation Guide

- **idx_scan = 0**: Index never used; safe to drop (unless recently created)
- Excludes constraint indexes which must be kept

### Index Hit Rate

```sql
SELECT
    sum(idx_blks_hit) AS idx_hit,
    sum(idx_blks_read) AS idx_read,
    round(sum(idx_blks_hit)::numeric / NULLIF(sum(idx_blks_hit) + sum(idx_blks_read), 0) * 100, 2) AS idx_hit_rate
FROM pg_statio_user_indexes;
```

#### Interpretation Guide

- **idx_hit_rate > 99%**: Excellent; indexes well-cached
- **idx_hit_rate < 95%**: May need more shared_buffers

---

## Configuration Settings

Important PostgreSQL parameters to monitor.

### Key Performance Settings

```sql
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN (
    'max_connections',
    'shared_buffers',
    'work_mem',
    'effective_cache_size',
    'maintenance_work_mem',
    'checkpoint_completion_target',
    'wal_buffers',
    'default_statistics_target',
    'random_page_cost',
    'effective_io_concurrency'
)
ORDER BY name;
```

### Memory Settings (Human-Readable)

```sql
SELECT name, setting, unit,
    CASE
        WHEN unit = '8kB' THEN pg_size_pretty(setting::bigint * 8192)
        WHEN unit = 'kB' THEN pg_size_pretty(setting::bigint * 1024)
        WHEN unit = 'MB' THEN pg_size_pretty(setting::bigint * 1024 * 1024)
        ELSE setting || ' ' || COALESCE(unit, '')
    END AS human_readable
FROM pg_settings
WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size')
ORDER BY name;
```

---

## Database Health Overview

General health metrics.

### Database Size

```sql
SELECT
    datname,
    pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;
```

### Cache Hit Ratio

Should be > 99% for OLTP workloads.

```sql
SELECT
    sum(heap_blks_hit) AS heap_hit,
    sum(heap_blks_read) AS heap_read,
    round(sum(heap_blks_hit)::numeric / NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100, 2) AS cache_hit_ratio
FROM pg_statio_user_tables;
```

#### Interpretation Guide

- **cache_hit_ratio > 99%**: Excellent; most data served from memory
- **cache_hit_ratio < 95%**: Consider increasing shared_buffers

### Transaction Statistics

```sql
SELECT
    xact_commit,
    xact_rollback,
    round(100.0 * xact_rollback / NULLIF(xact_commit + xact_rollback, 0), 2) AS rollback_pct,
    blks_read,
    blks_hit,
    round(100.0 * blks_hit / NULLIF(blks_read + blks_hit, 0), 2) AS cache_hit_pct
FROM pg_stat_database
WHERE datname = current_database();
```

#### Interpretation Guide

- **rollback_pct > 5%**: High rollback rate may indicate application issues
- **cache_hit_pct**: Database-level cache effectiveness

### Long-Running Queries

Queries running longer than 5 minutes.

```sql
SELECT
    pid,
    now() - pg_stat_activity.query_start AS duration,
    state,
    query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
    AND state != 'idle'
ORDER BY duration DESC;
```

#### Interpretation Guide

- Long-running queries may indicate missing indexes or lock contention
- Consider terminating with `pg_terminate_backend(pid)` if blocking others

### Lock Monitoring

Find blocked queries and their blockers.

```sql
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

#### Interpretation Guide

- **blocked_pid**: Process waiting for lock
- **blocking_pid**: Process holding lock; may need to be terminated
- Resolve by terminating blocking query or waiting for it to complete
