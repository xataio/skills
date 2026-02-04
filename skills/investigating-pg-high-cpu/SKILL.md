---
name: investigating-pg-high-cpu
description: Investigate and resolve high CPU usage in PostgreSQL databases. Use when database is slow, high CPU usage, CPU spike, performance degradation, queries are stuck, database unresponsive, slow queries, connection issues, or lock contention is suspected.
---

# PostgreSQL High CPU Investigation

## Prerequisites

**Required PostgreSQL version:** 9.6+

**Optional extensions:**

- `pg_stat_statements` - Required for historical slow query analysis (Step 5). Enable with:
  ```sql
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  ```

**Note:** Thresholds in this skill (e.g., 30-second query duration, 10% dead tuples) are defaults and should be adjusted based on your workload characteristics.

## Investigation Workflow

**Progress Checklist:**

```
- [ ] Step 1: Check active queries
- [ ] Step 2: Check lock contention
- [ ] Step 3: Check I/O metrics
- [ ] Step 4: Check vacuum statistics
- [ ] Step 5: Check slow queries (pg_stat_statements)
- [ ] Step 6: Check database logs
- [ ] Step 7: Summarize and take action
- [ ] Step 8: Verify resolution
```

### Step 1: Check Active Queries

First, identify currently running queries that may be consuming CPU resources.

**What to look for:**

- Queries with long duration (> 30 seconds for OLTP, > 5 minutes for analytics)
- Queries in "active" state consuming resources
- Queries with concerning wait events (Lock, IO, etc.)

Use the `active_queries` SQL from [references/cpu_investigation_queries.md](references/cpu_investigation_queries.md).

**Red flags:**

- Multiple identical queries running simultaneously (potential connection storm)
- Queries running for hours with "active" state
- High number of queries waiting on locks

### Step 2: Check Lock Contention

Blocked queries waiting on locks can cause cascading performance issues.

**What to look for:**

- Chains of blocked queries
- Long-held locks preventing other queries from executing
- Deadlock situations

Use the `blocked_queries` SQL from [references/cpu_investigation_queries.md](references/cpu_investigation_queries.md).

**Red flags:**

- Queries blocked for more than a few seconds
- Long blocking chains (A blocks B, B blocks C, etc.)
- Same tables involved in multiple lock conflicts

### Step 3: Check I/O Metrics

High CPU can be related to I/O bottlenecks causing queries to work harder.

**What to look for:**

- IOPS approaching provisioned limits
- High disk queue depth
- Correlation between I/O spikes and CPU spikes

Check cloud provider metrics or use system tools like `iostat`.

### Step 4: Check Vacuum Statistics

Table bloat from dead tuples causes inefficient table scans and higher CPU usage.

**What to look for:**

- Tables with high dead tuple counts
- Tables that haven't been vacuumed recently
- High modification counts since last analyze

Use the `vacuum_stats` SQL from [references/cpu_investigation_queries.md](references/cpu_investigation_queries.md).

**Red flags:**

- Dead tuples > 10% of live tuples
- Last vacuum/autovacuum was days ago
- n_mod_since_analyze is very high

### Step 5: Check Slow Queries (pg_stat_statements)

Identify historically problematic queries that may be contributing to CPU load.

**Requirements:** pg_stat_statements extension must be enabled.

Use the `slow_queries` SQL from [references/cpu_investigation_queries.md](references/cpu_investigation_queries.md).

**What to analyze:**

- Queries with high total_exec_time
- Queries with high mean_exec_time and high calls
- Queries with low rows returned but high shared_blks_hit (potential missing index)

### Step 6: Check Database Logs

Review recent logs for errors, warnings, or patterns.

**What to look for:**

- Repeated error messages
- Checkpoint warnings
- Connection errors or timeouts
- Deadlock detection messages

### Step 7: Summarize and Take Action

Based on findings, identify the root cause and apply appropriate resolution.

## Resolution Strategies

### For Long-Running Queries

```sql
-- Terminate a specific runaway query (use with caution)
SELECT pg_terminate_backend(pid);

-- Cancel a query without terminating the connection
SELECT pg_cancel_backend(pid);
```

**Best practices:**

- First try `pg_cancel_backend()` before `pg_terminate_backend()`
- Document which queries were terminated and why
- Investigate why the query ran long (missing index? bad plan?)

### For Lock Contention

```sql
-- Identify and terminate the blocking query
SELECT pg_terminate_backend(blocking_pid);
```

**Best practices:**

- Terminate the oldest blocker first
- Check if blocked queries can be retried automatically
- Review application code for long-held transactions

### For Table Bloat

```sql
-- Force vacuum on a specific table
VACUUM (VERBOSE) schema_name.table_name;

-- Aggressive vacuum if normal vacuum isn't enough
VACUUM (FULL, VERBOSE) schema_name.table_name;
-- WARNING: VACUUM FULL locks the table exclusively
```

**Best practices:**

- Run standard VACUUM first (non-blocking)
- Only use VACUUM FULL during maintenance windows
- Consider pg_repack for large tables as a non-blocking alternative

### For Outdated Statistics

```sql
-- Update statistics for a specific table
ANALYZE schema_name.table_name;

-- Update statistics for all tables
ANALYZE;
```

### For Missing Indexes

After identifying slow queries, analyze their execution plans:

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <query>;
```

Look for:

- Sequential scans on large tables
- High rows removed by filter
- Nested loops with high row counts

## Common CPU Issue Patterns

| Pattern          | Symptoms                          | Likely Cause                                         |
| ---------------- | --------------------------------- | ---------------------------------------------------- |
| Sudden spike     | CPU jumps from normal to 100%     | Runaway query, connection storm                      |
| Gradual increase | CPU slowly climbs over days/weeks | Table bloat, growing data without index optimization |
| Periodic spikes  | CPU spikes at regular intervals   | Scheduled jobs, maintenance tasks                    |
| Sustained high   | CPU consistently above 80%        | Under-provisioned, need query optimization           |

## Quick Diagnostic Commands

For rapid triage, run these in order:

1. **Count active connections by state:**

```sql
SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
```

2. **Find longest running query:**

```sql
SELECT pid, now() - query_start as duration, query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC
LIMIT 1;
```

3. **Check for lock waits:**

```sql
SELECT count(*) FROM pg_stat_activity WHERE wait_event_type = 'Lock';
```

## Resources

- [references/cpu_investigation_queries.md](references/cpu_investigation_queries.md) - Complete SQL queries for investigation

## Step 8: Verify Resolution

After taking action, verify the issue is resolved:

```sql
-- Quick verification query
SELECT
    count(*) FILTER (WHERE state = 'active') as active_queries,
    count(*) FILTER (WHERE wait_event_type = 'Lock') as lock_waits,
    max(EXTRACT(EPOCH FROM (now() - query_start))) as longest_query_secs
FROM pg_stat_activity
WHERE state != 'idle';
```

If CPU is still high, return to Step 1 with new data.

## Investigation Summary Template

After investigation, provide a summary in this format:

```
## High CPU Investigation Summary

**CPU Status:** [Current level] (was [previous level])

**Root Cause:**
[Primary cause identified]

**Actions Taken:**
- [Action 1 with result]
- [Action 2 with result]

**Queries Terminated:** [Count if any]

**Long-Term Recommendations:**
1. [Recommendation]
2. [Recommendation]

**Monitoring Notes:**
[Any patterns to watch for]
```
