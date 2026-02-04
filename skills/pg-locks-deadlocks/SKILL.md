---
name: pg-locks-deadlocks
description: |
  PostgreSQL Lock and Deadlock Investigation skill. Use this skill when users ask about:
  - Lock contention or blocking queries
  - Deadlock detection and resolution
  - Queries waiting for locks
  - Finding what is blocking a query
  - Lock timeout issues
  - Understanding PostgreSQL lock types
  - Resolving stuck or hanging queries
  - Transaction blocking problems
  - "Lock:relation", "Lock:tuple", "Lock:transactionid" wait events
---

# PostgreSQL Locks and Deadlocks

## Overview

This skill provides comprehensive guidance for detecting, analyzing, and resolving PostgreSQL lock contention and deadlocks. Lock issues are a common cause of application slowdowns and query timeouts in PostgreSQL databases.

## Quick Diagnosis Workflow

1. **Check for blocked queries** - Identify queries waiting for locks
2. **Identify the blocker** - Find which query/transaction is holding the lock
3. **Assess impact** - Determine how long queries have been blocked
4. **Resolve** - Either wait, cancel the blocker, or terminate the blocking session
5. **Prevent recurrence** - Implement best practices

## Detecting Blocked Queries

### Find All Blocked Queries with Their Blockers

This is the primary query for investigating lock contention:

```sql
WITH blocked_queries AS (
  SELECT
    blocked.pid as blocked_pid,
    blocked.query as blocked_query,
    blocking.pid as blocking_pid,
    blocking.query as blocking_query,
    EXTRACT(EPOCH FROM (NOW() - blocked.query_start))::INTEGER as blocked_duration
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
    AND blocked.pid != pg_backend_pid()
)
SELECT * FROM blocked_queries ORDER BY blocked_duration DESC;
```

**Output interpretation:**
- `blocked_pid`: The process waiting for a lock
- `blocked_query`: The query that is waiting
- `blocking_pid`: The process holding the lock
- `blocking_query`: The query holding the lock (may show last query if idle in transaction)
- `blocked_duration`: How long the query has been blocked (seconds)

### View Active Queries with Wait Information

```sql
SELECT
  pid,
  state,
  EXTRACT(EPOCH FROM (NOW() - query_start))::INTEGER as duration,
  wait_event_type,
  wait_event,
  query
FROM pg_stat_activity
WHERE state != 'idle' AND pid != pg_backend_pid()
ORDER BY duration DESC;
```

**Key wait events indicating lock issues:**
- `Lock:relation` - Waiting for a table-level lock
- `Lock:tuple` - Waiting for a row-level lock
- `Lock:transactionid` - Waiting for another transaction to complete

### Monitor All Locks on Relations

```sql
SELECT
  l.locktype,
  l.relation::regclass as table_name,
  l.mode,
  l.granted,
  a.usename,
  a.query,
  a.pid
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE l.relation IS NOT NULL
ORDER BY l.relation;
```

## Understanding Lock Types

PostgreSQL uses various lock modes with increasing levels of exclusivity:

| Lock Mode | Acquired By | Conflicts With |
|-----------|-------------|----------------|
| **AccessShareLock** | SELECT | AccessExclusiveLock |
| **RowShareLock** | SELECT FOR UPDATE/SHARE | ExclusiveLock, AccessExclusiveLock |
| **RowExclusiveLock** | INSERT, UPDATE, DELETE | ShareLock, ShareRowExclusiveLock, ExclusiveLock, AccessExclusiveLock |
| **ShareUpdateExclusiveLock** | VACUUM, ANALYZE, CREATE INDEX CONCURRENTLY | ShareUpdateExclusiveLock, ShareLock, ShareRowExclusiveLock, ExclusiveLock, AccessExclusiveLock |
| **ShareLock** | CREATE INDEX (non-concurrent) | RowExclusiveLock, ShareUpdateExclusiveLock, ShareRowExclusiveLock, ExclusiveLock, AccessExclusiveLock |
| **ShareRowExclusiveLock** | CREATE TRIGGER | RowExclusiveLock, ShareUpdateExclusiveLock, ShareLock, ShareRowExclusiveLock, ExclusiveLock, AccessExclusiveLock |
| **ExclusiveLock** | REFRESH MATERIALIZED VIEW CONCURRENTLY | RowShareLock and above |
| **AccessExclusiveLock** | DROP, ALTER TABLE, TRUNCATE, REINDEX, VACUUM FULL | All lock modes |

**Key insight:** `AccessExclusiveLock` blocks ALL other operations including SELECT. Operations like `ALTER TABLE`, `DROP TABLE`, `TRUNCATE`, and `VACUUM FULL` require this lock.

## Resolving Lock Issues

### Option 1: Cancel the Blocking Query (Soft)

Sends a cancel signal - query will stop but transaction remains open:

```sql
SELECT pg_cancel_backend(<blocking_pid>);
```

### Option 2: Terminate the Blocking Session (Hard)

Terminates the entire session - use when cancel doesn't work:

```sql
SELECT pg_terminate_backend(<blocking_pid>);
```

### View All Locks Held by a Specific Process

Before terminating, understand what locks the process holds:

```sql
SELECT * FROM pg_locks WHERE pid = <pid>;
```

## Deadlock Detection

PostgreSQL automatically detects and resolves deadlocks by terminating one of the involved transactions. This happens within `deadlock_timeout` (default: 1 second).

### Check Logs for Deadlocks

Look for messages containing:
```
deadlock detected
```

The log will show:
- Which processes were involved
- What queries they were running
- What locks they were waiting for
- Which process was terminated

### Current Deadlock Timeout Setting

```sql
SHOW deadlock_timeout;
```

## Lock Timeout Configuration

### Set Lock Timeout (Per Session)

Give up if lock cannot be acquired within the timeout:

```sql
SET lock_timeout = '5s';
```

### Set Statement Timeout (Per Session)

Overall statement execution timeout:

```sql
SET statement_timeout = '30s';
```

### Check Current Settings

```sql
SHOW lock_timeout;
SHOW statement_timeout;
SHOW idle_in_transaction_session_timeout;
```

### Configure at Database Level

```sql
ALTER DATABASE mydb SET lock_timeout = '10s';
ALTER DATABASE mydb SET statement_timeout = '60s';
ALTER DATABASE mydb SET idle_in_transaction_session_timeout = '300s';
```

## Preventing Lock Issues

### Best Practices

1. **Keep transactions short**
   - Commit or rollback as quickly as possible
   - Don't hold transactions open during user think time or external API calls

2. **Use consistent lock ordering**
   - Access tables in the same order across all transactions
   - This prevents deadlocks from circular waits

3. **Use appropriate isolation level**
   - Default `READ COMMITTED` is usually sufficient
   - Higher isolation levels increase lock contention

4. **Set idle_in_transaction_session_timeout**
   ```sql
   SET idle_in_transaction_session_timeout = '5min';
   ```
   - Automatically terminates sessions idle in an open transaction

5. **Index foreign key columns**
   - Without indexes, DELETE on parent table locks entire child table
   - With indexes, only affected rows are locked

6. **Use CONCURRENTLY for index operations**
   ```sql
   CREATE INDEX CONCURRENTLY idx_name ON table(column);
   REINDEX INDEX CONCURRENTLY idx_name;
   ```

7. **Avoid long-running queries during peak hours**
   - Large batch updates should run during maintenance windows
   - Consider breaking into smaller batches

### Application-Level Recommendations

- Implement retry logic with exponential backoff for lock timeout errors
- Use `SELECT ... FOR UPDATE SKIP LOCKED` when appropriate
- Consider advisory locks for application-level coordination

## Common Scenarios

### Scenario: ALTER TABLE Blocked by Long Query

**Problem:** `ALTER TABLE` needs `AccessExclusiveLock` but SELECT queries hold `AccessShareLock`

**Solution:**
1. Identify the blocking queries
2. Wait for them to complete or cancel them
3. Consider using `lock_timeout` on the ALTER to avoid blocking new queries

### Scenario: Batch UPDATE Blocking OLTP Queries

**Problem:** Large UPDATE locks many rows, blocking application queries

**Solution:**
1. Break into smaller batches with commits between
2. Add small delays between batches
3. Run during low-traffic periods

### Scenario: Frequent Deadlocks

**Problem:** Application frequently sees deadlock errors

**Solution:**
1. Analyze the queries involved (check logs)
2. Ensure consistent table access order
3. Consider reducing transaction scope
4. Index foreign key columns

## References

- PostgreSQL Documentation: [Explicit Locking](https://www.postgresql.org/docs/current/explicit-locking.html)
- PostgreSQL Documentation: [Lock Management Functions](https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-ADMIN-SIGNAL)
