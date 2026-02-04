# PostgreSQL Health Monitoring

## Contents

- [Quick Health Check](#quick-health-check)
- [Slow Query Check](#slow-query-check-requires-pg_stat_statements)
- [Table Health](#table-health)
- [Index Health](#index-health)
- [Replication Status](#replication-status-run-on-primary)
- [Configuration Check](#configuration-check)
- [Health Thresholds](#health-thresholds)

## Quick Health Check

```sql
-- Connection utilization
SELECT
    count(*) AS total_connections,
    count(*) FILTER (WHERE state != 'idle') AS active,
    current_setting('max_connections')::int AS max,
    round(100.0 * count(*) / current_setting('max_connections')::int, 2) AS utilization_pct
FROM pg_stat_activity;

-- Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;

-- Cache hit ratio (should be > 99%)
SELECT round(100.0 * sum(heap_blks_hit) / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0), 2) AS cache_hit_ratio
FROM pg_statio_user_tables;
```

## Slow Query Check (requires pg_stat_statements)

```sql
SELECT
    calls,
    round(mean_exec_time::numeric, 2) AS mean_ms,
    round(total_exec_time/1000) AS total_secs,
    LEFT(query, 80) AS query
FROM pg_stat_statements
WHERE mean_exec_time > 100  -- > 100ms average
ORDER BY total_exec_time DESC
LIMIT 10;
```

## Table Health

```sql
SELECT
    schemaname || '.' || relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS size,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_tuples,
    CASE WHEN n_live_tup > 0 THEN round(100.0 * n_dead_tup / n_live_tup, 2) ELSE 0 END AS dead_pct,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;
```

## Index Health

```sql
-- Tables with high sequential scan ratio (may need indexes)
SELECT
    schemaname || '.' || relname AS table_name,
    seq_scan, idx_scan,
    CASE WHEN (seq_scan + idx_scan) > 0
         THEN round(100.0 * seq_scan / (seq_scan + idx_scan), 2)
         ELSE 0 END AS seq_scan_pct,
    n_live_tup AS rows
FROM pg_stat_user_tables
WHERE n_live_tup > 10000 AND seq_scan > idx_scan
ORDER BY seq_scan DESC LIMIT 20;

-- Unused indexes (candidates for removal)
SELECT schemaname || '.' || relname AS table_name, indexrelname AS index,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indexrelid NOT IN (SELECT conindid FROM pg_constraint)
ORDER BY pg_relation_size(indexrelid) DESC LIMIT 20;
```

## Replication Status (run on primary)

```sql
SELECT client_addr, state, sync_state,
       pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag
FROM pg_stat_replication;
```

## Configuration Check

```sql
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN ('max_connections', 'shared_buffers', 'work_mem',
               'effective_cache_size', 'maintenance_work_mem');
```

## Health Thresholds

| Metric                 | Healthy | Warning | Critical |
| ---------------------- | ------- | ------- | -------- |
| Connection utilization | < 50%   | 50-80%  | > 80%    |
| Cache hit ratio        | > 99%   | 95-99%  | < 95%    |
| Dead tuple %           | < 5%    | 5-10%   | > 10%    |
| Replication lag        | < 1MB   | 1-100MB | > 100MB  |
