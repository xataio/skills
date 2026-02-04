# Connection Management

## Check Connection Status

```sql
SELECT
    count(*) AS total,
    current_setting('max_connections')::int AS max,
    round(100.0 * count(*) / current_setting('max_connections')::int, 2) AS utilization_pct,
    count(*) FILTER (WHERE state = 'active') AS active,
    count(*) FILTER (WHERE state = 'idle') AS idle,
    count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_txn
FROM pg_stat_activity;
```

## Connections by Source

```sql
SELECT application_name, client_addr, usename, state, count(*)
FROM pg_stat_activity
GROUP BY application_name, client_addr, usename, state
ORDER BY count(*) DESC;
```

## Find Problematic Connections

```sql
-- Long idle-in-transaction (holding locks!)
SELECT pid, usename, application_name, state,
       NOW() - xact_start AS transaction_age, query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND xact_start < NOW() - INTERVAL '5 minutes';

-- Old idle connections
SELECT pid, usename, application_name, state_change,
       NOW() - state_change AS idle_duration
FROM pg_stat_activity
WHERE state = 'idle' AND state_change < NOW() - INTERVAL '1 hour'
ORDER BY state_change LIMIT 20;
```

## Kill Connections

```sql
-- Kill old idle connections
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle' AND state_change < NOW() - INTERVAL '1 hour'
  AND pid != pg_backend_pid();

-- Kill idle-in-transaction > 10 minutes
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND xact_start < NOW() - INTERVAL '10 minutes'
  AND pid != pg_backend_pid();
```

## Configure Timeouts

```sql
-- Terminate idle transactions automatically
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';

-- Terminate idle sessions (PostgreSQL 14+)
ALTER SYSTEM SET idle_session_timeout = '30min';

-- Apply
SELECT pg_reload_conf();
```

## Connection States

| State                           | Description                     | Concern                      |
| ------------------------------- | ------------------------------- | ---------------------------- |
| `idle`                          | Waiting for work                | Low - watch for accumulation |
| `active`                        | Executing query                 | Normal                       |
| `idle in transaction`           | Transaction open, not executing | **High** - holding locks     |
| `idle in transaction (aborted)` | Failed transaction              | **Critical** - must ROLLBACK |

## max_connections Guidelines

| Instance Size | vCPU | Recommended           |
| ------------- | ---- | --------------------- |
| Small         | 2-4  | 100-200               |
| Medium        | 4-8  | 200-500               |
| Large         | 8-16 | 500-1000              |
| XLarge        | 16+  | Use connection pooler |

**For > 500 connections:** Implement PgBouncer or pgpool-II.

## Increase max_connections (requires restart)

```sql
ALTER SYSTEM SET max_connections = 500;
-- Then restart PostgreSQL
```
