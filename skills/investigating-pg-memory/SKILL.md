---
name: investigating-pg-memory
description: Investigate and resolve PostgreSQL low freeable memory issues, OOM errors, and memory pressure. Use when users mention low memory, out of memory, OOM errors, freeable memory concerns, memory pressure, or need to optimize PostgreSQL memory settings like shared_buffers or work_mem.
---

# PostgreSQL Low Memory Investigation

## Prerequisites

**Required PostgreSQL version:** 9.6+

**Optional extensions:**

- `pg_stat_statements` - Required for identifying queries creating temporary files. Enable with:
  ```sql
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  ```

**Note:** Memory thresholds in this skill (e.g., 25% RAM for shared_buffers) are guidelines and should be adjusted based on your specific workload and instance characteristics.

## Investigation Workflow

**Progress Checklist:**

```
- [ ] Step 1: Check freeable memory metrics
- [ ] Step 2: Compare against instance capacity
- [ ] Step 3: Check logs for memory issues
- [ ] Step 4: Analyze active connections
- [ ] Step 5: Review memory configuration
- [ ] Apply resolution strategies
- [ ] Verify: Confirm memory pressure resolved
```

### Step 1: Check Freeable Memory Metrics

Get current memory metrics from your monitoring system or cloud provider dashboard:

- **AWS RDS**: Check the `FreeableMemory` CloudWatch metric
- **GCP Cloud SQL**: Check `database/memory/utilization` metric
- **Self-managed**: Use system tools like `free -m` or check `/proc/meminfo`

Critical thresholds:

- **Warning**: Below 25% of total RAM
- **Critical**: Below 10% of total RAM or under 1GB

### Step 2: Compare Against Instance Capacity

Get cluster/instance details and compare freeable memory with total available memory:

```sql
-- Check PostgreSQL's view of memory settings
SHOW shared_buffers;
SHOW work_mem;
SHOW maintenance_work_mem;
SHOW effective_cache_size;
```

Compare these values against your instance's total RAM to ensure proper ratios.

### Step 3: Check Logs for Memory Issues

Review PostgreSQL logs for memory pressure indicators:

**Critical patterns to search for:**

- `out of memory` - OOM errors (CRITICAL - requires immediate action)
- `could not resize shared memory segment`
- `temporary file`
- `memory exhausted`

OOM errors indicate the system is critically low on memory and processes are being killed.

### Step 4: Analyze Active Connections

Identify if specific users or applications are causing excessive memory usage:

```sql
-- Connection summary grouped by state/user/application
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

```sql
-- Check for long-running queries consuming memory
SELECT
    pid,
    usename,
    application_name,
    state,
    query_start,
    now() - query_start AS duration,
    wait_event_type,
    wait_event,
    LEFT(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND query NOT LIKE '%pg_stat_activity%'
ORDER BY query_start ASC;
```

### Step 5: Review Memory Configuration

Analyze current memory settings:

```sql
SELECT name, setting, unit, source, short_desc AS description
FROM pg_settings
WHERE name IN (
  'shared_buffers',
  'work_mem',
  'maintenance_work_mem',
  'effective_cache_size',
  'max_connections'
);
```

## Memory Configuration Guidelines

### Recommended Settings Based on Total RAM

| Setting                | Recommendation                                  | Notes                                    |
| ---------------------- | ----------------------------------------------- | ---------------------------------------- |
| `shared_buffers`       | 25% of RAM (max ~8GB)                           | Larger values have diminishing returns   |
| `work_mem`             | (RAM - shared_buffers) / (max_connections \* 3) | Per-operation, not per-connection        |
| `maintenance_work_mem` | 5% of RAM or 1-2GB max                          | Used for VACUUM, CREATE INDEX            |
| `effective_cache_size` | ~75% of RAM                                     | Helps query planner, no memory allocated |
| `max_connections`      | Based on actual needs                           | Each connection reserves memory          |
| `huge_pages`           | `try` or `on` for shared_buffers >= 8GB         | Reduces memory overhead, improves TLB    |

### Example Calculations (32GB RAM Instance)

```
shared_buffers = 8GB (25% of 32GB)
work_mem = (32GB - 8GB) / (100 connections * 3) = ~80MB
maintenance_work_mem = 1.6GB (5% of 32GB)
effective_cache_size = 24GB (75% of 32GB)
```

## Common Memory Issues

### 1. Too Many Connections

**Symptoms:**

- High connection count in `pg_stat_activity`
- Memory usage scales with connection count

**Resolution:**

```sql
-- Check current vs max connections
SELECT
    current_setting('max_connections')::int AS max_connections,
    (SELECT count(*) FROM pg_stat_activity) AS current_connections;
```

### 2. Shared Buffers Too High

**Symptoms:**

- `shared_buffers` exceeds 25% of RAM
- System swapping observed

**Resolution:**

- Reduce `shared_buffers` to 25% of RAM or 8GB maximum
- Restart PostgreSQL (requires restart, not just reload)

### 3. Memory-Intensive Queries

**Symptoms:**

- Queries with large sorts, hash joins, or aggregations
- Temporary files being created

**Resolution:**

```sql
-- Find queries creating temporary files
SELECT
    query,
    calls,
    temp_blks_read,
    temp_blks_written
FROM pg_stat_statements
WHERE temp_blks_written > 0
ORDER BY temp_blks_written DESC
LIMIT 10;
```

### 4. Missing Connection Pooler

**Symptoms:**

- Direct application connections to database
- Connection count matches application server count

**Resolution:**

- Implement PgBouncer or similar connection pooler
- Use transaction-level pooling for web applications

### 5. Memory Leaks in Extensions

**Symptoms:**

- Memory usage grows over time without traffic increase
- Specific extensions showing high memory in logs

**Resolution:**

- Review and update extensions
- Consider removing problematic extensions
- Schedule periodic restarts if necessary

## Resolution Strategies

### Immediate Actions (No Restart Required)

1. **Terminate memory-heavy queries:**

```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'active'
  AND query_start < now() - interval '1 hour';
```

2. **Reduce work_mem temporarily:**

```sql
ALTER SYSTEM SET work_mem = '32MB';
SELECT pg_reload_conf();
```

### Medium-Term Actions (May Require Restart)

1. **Implement connection pooling** - PgBouncer configuration example:

```ini
[databases]
mydb = host=localhost dbname=mydb

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
```

2. **Reduce shared_buffers** (requires restart)

3. **Optimize queries** creating temporary files

### Long-Term Actions

1. **Scale up the instance** if no configuration improvements resolve the issue

2. **Review application patterns** - fix connection leaks, implement proper pooling

## Cloud Provider Instance Recommendations

### AWS RDS

For memory-optimized workloads, consider:

- **r6g family**: Memory-optimized with Graviton2 processors
- **r5 family**: Previous generation memory-optimized
- **x2g family**: Extreme memory ratios

### GCP Cloud SQL

For high-memory requirements:

- **High-memory machine types** (e.g., `db-highmem-*`)
- Custom machine types with higher memory-to-CPU ratios

### Azure Database for PostgreSQL

- **Memory Optimized tier** for memory-intensive workloads
- Ev4/Ev5 series SKUs

## Quick Reference Queries

```sql
-- All-in-one memory investigation query
WITH memory_settings AS (
    SELECT name, setting, unit
    FROM pg_settings
    WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem',
                   'effective_cache_size', 'max_connections')
),
connection_stats AS (
    SELECT
        count(*) AS total_connections,
        count(*) FILTER (WHERE state = 'active') AS active,
        count(*) FILTER (WHERE state = 'idle') AS idle,
        count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_txn
    FROM pg_stat_activity
)
SELECT
    'Settings' AS category,
    m.name AS item,
    m.setting || COALESCE(' ' || m.unit, '') AS value
FROM memory_settings m
UNION ALL
SELECT
    'Connections' AS category,
    'total/active/idle/idle_in_txn' AS item,
    c.total_connections || '/' || c.active || '/' || c.idle || '/' || c.idle_in_txn AS value
FROM connection_stats c;
```

## Verification

After taking action, verify memory pressure is resolved by checking:

- Cloud provider freeable memory metric
- `free -m` on self-managed instances
- No new OOM errors in logs

## Investigation Summary Template

After investigation, provide a summary in this format:

```
## Memory Investigation Summary

**Memory Status:** [Healthy / Warning / Critical]
**Freeable Memory:** [Current value]

**Root Cause:**
[Primary cause of memory pressure]

**Actions Taken:**
- [Action 1]
- [Action 2]

**Configuration Changes:**
| Parameter | Old Value | New Value |
|-----------|-----------|-----------|
| [param]   | [old]     | [new]     |

**Long-Term Recommendations:**
1. [Recommendation]
2. [Recommendation]
```
