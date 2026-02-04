# High CPU Investigation

## Step 1: Check Active Queries

```sql
SELECT pid, state,
       EXTRACT(EPOCH FROM (NOW() - query_start))::int AS duration_secs,
       wait_event_type, wait_event,
       LEFT(query, 100) AS query
FROM pg_stat_activity
WHERE state != 'idle' AND pid != pg_backend_pid()
ORDER BY duration_secs DESC;
```

**Wait event interpretation:**

| wait_event_type | Meaning                               |
| --------------- | ------------------------------------- |
| NULL            | Actively using CPU - may be the cause |
| Lock            | Waiting for lock                      |
| IO              | Waiting for disk I/O                  |
| LWLock          | Internal PostgreSQL contention        |

## Step 2: Check Lock Contention

```sql
SELECT
    blocked.pid AS blocked_pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query,
    EXTRACT(EPOCH FROM (NOW() - blocked.query_start))::int AS blocked_secs
FROM pg_stat_activity blocked
JOIN pg_locks blocked_locks ON blocked.pid = blocked_locks.pid
JOIN pg_locks blocking_locks ON blocked_locks.locktype = blocking_locks.locktype
    AND blocked_locks.database IS NOT DISTINCT FROM blocking_locks.database
    AND blocked_locks.relation IS NOT DISTINCT FROM blocking_locks.relation
    AND blocked_locks.pid != blocking_locks.pid
JOIN pg_stat_activity blocking ON blocking_locks.pid = blocking.pid
WHERE NOT blocked_locks.granted
ORDER BY blocked_secs DESC;
```

## Step 3: Check Vacuum Status

```sql
SELECT schemaname, relname, n_dead_tup, n_live_tup,
       CASE WHEN n_live_tup > 0 THEN round(100.0 * n_dead_tup / n_live_tup, 2) ELSE 0 END AS dead_pct,
       last_vacuum, last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC LIMIT 20;
```

## Step 4: Check Slow Queries (pg_stat_statements)

```sql
SELECT calls, round(total_exec_time/1000) AS total_secs,
       round(mean_exec_time::numeric, 2) AS mean_ms, query
FROM pg_stat_statements
ORDER BY total_exec_time DESC LIMIT 10;
```

## Resolution

### Kill Runaway Query

```sql
SELECT pg_cancel_backend(<pid>);   -- Soft (cancel query)
SELECT pg_terminate_backend(<pid>); -- Hard (terminate connection)
```

### Fix Table Bloat

```sql
VACUUM (VERBOSE) schema.table_name;
-- Or for severe bloat (locks table):
VACUUM FULL schema.table_name;
```

### Update Statistics

```sql
ANALYZE schema.table_name;
```

## Common Patterns

| Pattern          | Symptoms             | Likely Cause                          |
| ---------------- | -------------------- | ------------------------------------- |
| Sudden spike     | CPU jumps to 100%    | Runaway query, connection storm       |
| Gradual increase | CPU climbs over days | Table bloat, growing data             |
| Periodic spikes  | Regular intervals    | Scheduled jobs, maintenance           |
| Sustained high   | Consistently > 80%   | Under-provisioned, needs optimization |
