# Locks and Deadlocks

## Find Blocked Queries

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
    AND blocked_locks.page IS NOT DISTINCT FROM blocking_locks.page
    AND blocked_locks.tuple IS NOT DISTINCT FROM blocking_locks.tuple
    AND blocked_locks.virtualxid IS NOT DISTINCT FROM blocking_locks.virtualxid
    AND blocked_locks.transactionid IS NOT DISTINCT FROM blocking_locks.transactionid
    AND blocked_locks.classid IS NOT DISTINCT FROM blocking_locks.classid
    AND blocked_locks.objid IS NOT DISTINCT FROM blocking_locks.objid
    AND blocked_locks.objsubid IS NOT DISTINCT FROM blocking_locks.objsubid
    AND blocked_locks.pid != blocking_locks.pid
JOIN pg_stat_activity blocking ON blocking_locks.pid = blocking.pid
WHERE NOT blocked_locks.granted
ORDER BY blocked_secs DESC;
```

## Quick Lock Check

```sql
SELECT pid, wait_event_type, wait_event, state, LEFT(query, 80) AS query
FROM pg_stat_activity
WHERE wait_event_type = 'Lock';
```

## Resolve Locks

```sql
-- Cancel query (soft)
SELECT pg_cancel_backend(<blocking_pid>);

-- Terminate connection (hard)
SELECT pg_terminate_backend(<blocking_pid>);
```

## Lock Types

| Lock Mode           | Acquired By                        | Conflicts With            |
| ------------------- | ---------------------------------- | ------------------------- |
| AccessShareLock     | SELECT                             | AccessExclusiveLock       |
| RowShareLock        | SELECT FOR UPDATE                  | Exclusive locks           |
| RowExclusiveLock    | INSERT, UPDATE, DELETE             | Share and Exclusive locks |
| AccessExclusiveLock | DROP, ALTER, TRUNCATE, VACUUM FULL | **Everything**            |

**Key insight:** `AccessExclusiveLock` blocks ALL operations including SELECT.

## Configure Timeouts

```sql
-- Give up waiting for lock after 5s
SET lock_timeout = '5s';

-- Statement timeout
SET statement_timeout = '30s';

-- Idle in transaction timeout
SET idle_in_transaction_session_timeout = '5min';

-- Database-level
ALTER DATABASE mydb SET lock_timeout = '10s';
```

## Enable Lock Wait Logging

```sql
ALTER SYSTEM SET log_lock_waits = on;
SELECT pg_reload_conf();
```

## Deadlock Detection

PostgreSQL auto-detects deadlocks within `deadlock_timeout` (default 1s) and terminates one transaction.

```sql
SHOW deadlock_timeout;
```

Check logs for `deadlock detected` messages.

## Prevention Best Practices

1. **Keep transactions short** - Commit/rollback quickly
2. **Consistent lock ordering** - Access tables in same order
3. **Index foreign keys** - Prevents full table locks on DELETE
4. **Use CONCURRENTLY** - `CREATE INDEX CONCURRENTLY`, `REINDEX CONCURRENTLY`
5. **Avoid long queries during DDL** - Schedule ALTER TABLE during low traffic

## Common Scenarios

| Scenario              | Problem                      | Solution                                 |
| --------------------- | ---------------------------- | ---------------------------------------- |
| ALTER TABLE blocked   | SELECTs hold AccessShareLock | Wait or cancel blocking queries          |
| Batch UPDATE blocking | Locks many rows              | Break into smaller batches               |
| Frequent deadlocks    | Circular lock dependencies   | Consistent table access order, index FKs |
