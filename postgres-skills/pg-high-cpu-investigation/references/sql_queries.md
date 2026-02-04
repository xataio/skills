# PostgreSQL High CPU Investigation SQL Queries

## Active Queries

Query to get currently active queries from pg_stat_activity:

```sql
SELECT
  pid,
  state,
  EXTRACT(EPOCH FROM (NOW() - query_start))::INTEGER as duration_seconds,
  wait_event_type,
  wait_event,
  usename,
  application_name,
  client_addr,
  query
FROM pg_stat_activity
WHERE state != 'idle'
  AND pid != pg_backend_pid()
ORDER BY duration_seconds DESC
LIMIT 500;
```

### Interpretation Guide

- **state**: 'active' means currently executing, 'idle in transaction' means holding a transaction open
- **duration_seconds**: Time since query started; long durations may indicate problems
- **wait_event_type**: NULL means actively running on CPU; 'Lock' means waiting for locks; 'IO' means waiting for disk
- **wait_event**: Specific wait event within the type

## Blocked Queries (Lock Contention)

Query to find queries waiting on locks and their blockers:

```sql
WITH blocked_queries AS (
  SELECT
    blocked.pid as blocked_pid,
    blocked.usename as blocked_user,
    blocked.query as blocked_query,
    EXTRACT(EPOCH FROM (NOW() - blocked.query_start))::INTEGER as blocked_duration_seconds,
    blocking.pid as blocking_pid,
    blocking.usename as blocking_user,
    blocking.query as blocking_query,
    EXTRACT(EPOCH FROM (NOW() - blocking.query_start))::INTEGER as blocking_duration_seconds
  FROM pg_stat_activity blocked
  JOIN pg_locks blocked_locks ON blocked.pid = blocked_locks.pid
  JOIN pg_locks blocking_locks ON blocked_locks.locktype = blocking_locks.locktype
    AND blocked_locks.database IS NOT DISTINCT FROM blocking_locks.database
    AND blocked_locks.relation IS NOT DISTINCT FROM blocking_locks.relation
    AND blocked_locks.pid != blocking_locks.pid
  JOIN pg_stat_activity blocking ON blocking_locks.pid = blocking.pid
  WHERE NOT blocked_locks.granted
    AND blocked.pid != pg_backend_pid()
)
SELECT * FROM blocked_queries
ORDER BY blocked_duration_seconds DESC;
```

### Interpretation Guide

- **blocked_pid/blocking_pid**: Process IDs involved in the lock conflict
- **blocked_duration_seconds**: How long the blocked query has been waiting
- **blocking_query**: The query holding the lock (may need to be terminated)

## Vacuum Statistics

Query to check vacuum status and identify tables with bloat:

```sql
SELECT
  schemaname,
  relname as table_name,
  last_vacuum,
  last_autovacuum,
  vacuum_count,
  autovacuum_count,
  n_dead_tup as dead_tuples,
  n_live_tup as live_tuples,
  CASE
    WHEN n_live_tup > 0
    THEN ROUND((n_dead_tup::numeric / n_live_tup * 100), 2)
    ELSE 0
  END as dead_tuple_percent,
  n_mod_since_analyze as modifications_since_analyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 50;
```

### Interpretation Guide

- **dead_tuples**: Rows that have been deleted or updated but not yet vacuumed
- **dead_tuple_percent**: Percentage of dead tuples vs live; >10% is concerning
- **last_vacuum/last_autovacuum**: When the table was last cleaned up
- **modifications_since_analyze**: Changes since statistics were updated; high values mean potentially stale statistics

## Slow Queries (pg_stat_statements)

Query to identify historically slow queries (requires pg_stat_statements extension):

```sql
SELECT
  queryid,
  calls,
  ROUND(total_exec_time::numeric, 2) as total_exec_time_ms,
  ROUND(mean_exec_time::numeric, 2) as mean_exec_time_ms,
  ROUND(min_exec_time::numeric, 2) as min_exec_time_ms,
  ROUND(max_exec_time::numeric, 2) as max_exec_time_ms,
  rows,
  ROUND((shared_blks_hit + shared_blks_read)::numeric / NULLIF(calls, 0), 2) as avg_blocks_per_call,
  query
FROM pg_stat_statements
WHERE calls > 0
ORDER BY total_exec_time DESC
LIMIT 50;
```

### Interpretation Guide

- **total_exec_time_ms**: Total time spent on this query across all executions
- **mean_exec_time_ms**: Average execution time
- **calls**: Number of times this query was executed
- **rows**: Total rows returned
- **avg_blocks_per_call**: Data pages accessed per call; high values with low rows may indicate missing index

## Connection Summary

Quick check of connection states:

```sql
SELECT
  state,
  wait_event_type,
  count(*) as count
FROM pg_stat_activity
WHERE pid != pg_backend_pid()
GROUP BY state, wait_event_type
ORDER BY count DESC;
```

## Table Size and Bloat Estimation

Estimate table bloat (more accurate than just dead tuples):

```sql
SELECT
  schemaname || '.' || relname as table_name,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || relname)) as total_size,
  pg_size_pretty(pg_relation_size(schemaname || '.' || relname)) as table_size,
  pg_size_pretty(pg_indexes_size(schemaname || '.' || relname::regclass)) as indexes_size,
  n_live_tup as live_tuples,
  n_dead_tup as dead_tuples
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname || '.' || relname) DESC
LIMIT 20;
```

## Index Usage Statistics

Check if indexes are being used:

```sql
SELECT
  schemaname || '.' || relname as table_name,
  indexrelname as index_name,
  idx_scan as index_scans,
  idx_tup_read as tuples_read,
  idx_tup_fetch as tuples_fetched,
  pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC
LIMIT 30;
```

### Interpretation Guide

- **index_scans = 0**: Index is never used; candidate for removal
- **Low idx_scan with large index_size**: Wasted space and maintenance overhead

## Replication Lag (if applicable)

Check replication status on primary:

```sql
SELECT
  client_addr,
  state,
  sent_lsn,
  write_lsn,
  flush_lsn,
  replay_lsn,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) as lag_bytes
FROM pg_stat_replication;
```

## Cache Hit Ratio

Check buffer cache effectiveness:

```sql
SELECT
  sum(heap_blks_hit) as heap_hits,
  sum(heap_blks_read) as heap_reads,
  ROUND(
    sum(heap_blks_hit)::numeric /
    NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100,
    2
  ) as cache_hit_ratio_percent
FROM pg_statio_user_tables;
```

### Interpretation Guide

- **cache_hit_ratio_percent > 99%**: Excellent, most data served from memory
- **cache_hit_ratio_percent < 90%**: May need more memory or better query optimization
