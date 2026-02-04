---
name: monitoring-pg-health
description: PostgreSQL general health monitoring and performance assessment. Use when performing routine database health checks, monitoring connections, analyzing slow queries, reviewing database metrics, or assessing overall PostgreSQL performance.
---

# PostgreSQL General Monitoring

## Prerequisites

**Required PostgreSQL version:** 9.6+

**Optional extensions:**

- `pg_stat_statements` - Required for slow query analysis (Step 3). Enable with:
  ```sql
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  ```

**Note:** Thresholds in this skill (e.g., 80% connection utilization, 2-second query threshold) are defaults and should be adjusted based on your workload characteristics.

## Monitoring Workflow

**Progress Checklist:**

```
- [ ] Step 1: Check connection statistics
- [ ] Step 2: Review key system metrics
- [ ] Step 3: Evaluate slow queries
- [ ] Step 4: Analyze table statistics
- [ ] Step 5: Check important settings
- [ ] Step 6: Check replication status (if applicable)
- [ ] Step 7: Review database logs
- [ ] Step 8: Document findings
```

### Step 1: Check Connection Statistics

Monitor connection utilization to ensure the database isn't approaching connection limits.

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

**What to look for:**

- Connection utilization should stay below 80%
- High non_idle_connections may indicate query bottlenecks
- Sudden spikes warrant investigation

### Step 2: Review Key System Metrics

Check these critical areas:

| Metric           | Healthy Range             | Warning Signs    |
| ---------------- | ------------------------- | ---------------- |
| CPU Utilization  | < 80% sustained           | Consistent > 90% |
| Freeable Memory  | > 20% available           | < 10% available  |
| Read/Write IOPS  | Within provisioned limits | Sustained spikes |
| Disk Queue Depth | 0-1                       | Consistently > 0 |

### Step 3: Evaluate Slow Queries

Identify queries consuming the most resources using pg_stat_statements:

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

**Note:** Requires `pg_stat_statements` extension to be enabled.

### Step 4: Analyze Table Statistics

Review table sizes and access patterns:

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

**What to look for:**

- Tables with high seq_scan and low idx_scan may need indexing
- Large tables with many sequential scans indicate performance issues

### Step 5: Check Important Settings

Review critical PostgreSQL configuration parameters:

```sql
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN (
    'max_connections',
    'shared_buffers',
    'work_mem',
    'effective_cache_size',
    'maintenance_work_mem'
)
ORDER BY name;
```

**Recommended baselines:**

- `shared_buffers`: 25% of system RAM
- `effective_cache_size`: 50-75% of system RAM
- `work_mem`: Start with 4MB, increase for complex queries
- `maintenance_work_mem`: 512MB-1GB for maintenance operations

### Step 6: Check Replication Status (If Applicable)

For databases with replicas, check replication lag:

```sql
-- Run on primary to see replica lag
SELECT
    client_addr,
    state,
    sent_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_pretty
FROM pg_stat_replication;
```

**What to look for:**
- `lag_bytes > 0` indicates replica is behind
- Sustained high lag may indicate network issues or replica under-provisioning

### Step 7: Review Database Logs

Check recent logs for warnings and errors:

- Authentication failures
- Connection timeouts
- Deadlock occurrences
- Out of memory errors
- Replication lag warnings

### Step 8: Document Findings

Record all findings including:

- Current metric values and thresholds
- Any issues discovered and actions taken
- Recurring patterns requiring attention
- Recommendations for optimization

## Quick Health Check

For a rapid assessment, run these queries in sequence:

1. **Connection health** - Are we running out of connections?
2. **Slow query check** - Any queries taking > 2 seconds?
3. **Table bloat** - Tables needing VACUUM or reindex?

## Resources

Additional SQL queries and reference material are available in:

- [references/monitoring_queries.md](references/monitoring_queries.md) - Complete collection of monitoring queries with interpretation guides

## Health Check Summary Template

After assessment, provide a summary in this format:

```
## Database Health Check Summary

**Overall Status:** [Healthy / Warning / Critical]

**Key Metrics:**
- Connection utilization: X%
- Slow queries (>2s): X found
- Tables needing vacuum: X

**Issues Found:**
1. [Issue with severity]
2. [Issue with severity]

**Recommendations:**
1. [Action item with priority]
2. [Action item with priority]

**Next Review:** [Suggested timeframe]
```
