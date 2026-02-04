---
name: pg-connection-investigation
description: Investigate and resolve PostgreSQL high connection count issues. Use when users mention connection count problems, too many connections, max_connections errors, connection pool exhaustion, connection leaks, idle connections, or need to analyze pg_stat_activity for connection issues.
---

# PostgreSQL High Connection Count Investigation

## Overview

This skill provides a systematic approach to investigating and resolving high connection count issues in PostgreSQL databases. It guides you through connection analysis, identifying problematic patterns, and implementing solutions.

## Investigation Workflow

Follow this step-by-step process when investigating connection issues:

### Step 1: Get Connection Stats

First, check current connection utilization:

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
    (SELECT setting AS max_connections
     FROM pg_settings
     WHERE name = 'max_connections') B;
```

**Decision Point:**
- If utilization < 20%: Connection count is healthy. Stop investigation unless specific issues reported.
- If utilization >= 20%: Continue to Step 2.

### Step 2: Analyze Connection Trend

Check connection count over time to identify trends:

```sql
-- Check current snapshot of connection ages
SELECT
    date_trunc('minute', backend_start) AS connection_time,
    count(*) AS connections_opened
FROM pg_stat_activity
WHERE backend_start > NOW() - INTERVAL '1 hour'
GROUP BY 1
ORDER BY 1;
```

**Evaluate:**
- Is the trend upward? Calculate time until max_connections is reached.
- **ALERT**: If max_connections will be reached within 1 hour, immediate action required.

### Step 3: Evaluate Instance Configuration

Get instance and configuration info:

```sql
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN ('max_connections', 'superuser_reserved_connections',
               'idle_in_transaction_session_timeout', 'idle_session_timeout',
               'statement_timeout');
```

**Evaluate:**
- Is max_connections appropriate for instance type? (See guidelines below)
- Are there many idle connections that could be cleaned up?
- Are timeout settings configured?

### Step 4: Identify Connection Sources

Get connection groups overview to identify where bulk connections originate:

```sql
SELECT
    count(*) AS total_connections,
    state,
    usename AS user,
    application_name,
    client_addr,
    wait_event_type,
    wait_event
FROM pg_stat_activity
GROUP BY state, usename, application_name, client_addr, wait_event_type, wait_event
ORDER BY total_connections DESC;
```

**Look for:**
- Large groups of "idle in transaction" connections (problematic - holding locks)
- Many connections from single application/IP (potential connection leak)
- Patterns in wait_event (blocking issues)

### Step 5: Analyze Idle Connections

If many idle connections exist, identify the oldest ones:

```sql
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    state_change,
    NOW() - state_change AS idle_duration,
    query_start,
    NOW() - query_start AS time_since_last_query
FROM pg_stat_activity
WHERE state = 'idle'
ORDER BY state_change ASC
LIMIT 20;
```

### Step 6: Generate Summary and Recommendations

Based on findings, provide:
1. Root cause identification
2. Immediate actions (if critical)
3. Long-term recommendations

## Connection States Reference

| State | Description | Concern Level |
|-------|-------------|---------------|
| `idle` | Connection open but not executing | Low - but watch for accumulation |
| `active` | Currently executing a query | Normal |
| `idle in transaction` | In a transaction but not executing | **High** - holding locks, blocking others |
| `idle in transaction (aborted)` | Transaction failed, waiting for ROLLBACK | **Critical** - must be resolved |

## max_connections Guidelines

Recommended settings based on instance size:

| Instance Size | vCPU | Recommended max_connections |
|---------------|------|----------------------------|
| Small | 2-4 | 100-200 |
| Medium | 4-8 | 200-500 |
| Large | 8-16 | 500-1000 |
| XLarge | 16+ | 1000+ (consider pooling) |

**Important:** For applications requiring > 500 connections, implement connection pooling (PgBouncer, pgpool-II).

## Remediation Actions

### Kill Old Idle Connections (Use Carefully)

```sql
-- Preview connections that would be terminated
SELECT pid, usename, application_name, client_addr, state_change,
       NOW() - state_change AS idle_duration
FROM pg_stat_activity
WHERE state = 'idle'
  AND state_change < NOW() - INTERVAL '1 hour'
  AND pid != pg_backend_pid();

-- Kill connections idle for more than 1 hour (EXECUTE WITH CAUTION)
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
  AND state_change < NOW() - INTERVAL '1 hour'
  AND pid != pg_backend_pid();
```

### Kill Idle in Transaction Connections

```sql
-- Preview problematic connections
SELECT pid, usename, application_name, state,
       NOW() - xact_start AS transaction_duration,
       query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND xact_start < NOW() - INTERVAL '10 minutes';

-- Terminate them (EXECUTE WITH CAUTION)
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND xact_start < NOW() - INTERVAL '10 minutes'
  AND pid != pg_backend_pid();
```

## Long-Term Resolution Strategies

### 1. Implement Connection Pooling
- **PgBouncer**: Lightweight, recommended for most use cases
- **pgpool-II**: More features, higher complexity
- Configure in transaction or session pooling mode based on needs

### 2. Configure Timeout Settings
```sql
-- Set idle in transaction timeout (terminates idle transactions)
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';

-- Set idle session timeout (terminates idle connections - PostgreSQL 14+)
ALTER SYSTEM SET idle_session_timeout = '30min';

-- Apply changes
SELECT pg_reload_conf();
```

### 3. Application-Level Fixes
- Review connection handling code
- Ensure connections are properly closed/returned to pool
- Implement connection timeouts in application
- Use connection health checks

### 4. Adjust max_connections
```sql
-- Check current setting
SHOW max_connections;

-- To change (requires restart):
ALTER SYSTEM SET max_connections = 500;
-- Then restart PostgreSQL
```

## Quick Diagnosis Queries

### Connection Count by State
```sql
SELECT state, count(*)
FROM pg_stat_activity
GROUP BY state
ORDER BY count DESC;
```

### Connections by Application
```sql
SELECT application_name, count(*)
FROM pg_stat_activity
GROUP BY application_name
ORDER BY count DESC;
```

### Connections by User
```sql
SELECT usename, count(*)
FROM pg_stat_activity
GROUP BY usename
ORDER BY count DESC;
```

### Long-Running Transactions
```sql
SELECT pid, usename, application_name, state,
       NOW() - xact_start AS transaction_age,
       query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
ORDER BY xact_start ASC
LIMIT 10;
```
