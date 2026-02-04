---
name: maintaining-pg-vacuum
description: PostgreSQL vacuum and table maintenance. Use when working with VACUUM operations, autovacuum configuration, dead tuples and table bloat analysis, transaction ID wraparound prevention, table maintenance, space reclamation, or monitoring vacuum progress and statistics.
---

# PostgreSQL Vacuum and Maintenance

## Prerequisites

**Required PostgreSQL version:** 9.6+ (pg_stat_progress_vacuum requires 9.6+)

**No extensions required** - All queries use built-in system views (pg_stat_user_tables, pg_settings, pg_stat_progress_vacuum).

**Note:** Autovacuum thresholds (e.g., 20% scale factor) are PostgreSQL defaults. This skill provides guidance on adjusting them for your workload.

## Understanding VACUUM

### What VACUUM Does

VACUUM is essential for PostgreSQL health and performs these critical functions:

1. **Reclaims storage from dead tuples** - Deleted or updated rows leave behind "dead tuples" that VACUUM marks for reuse
2. **Updates visibility map** - Enables efficient index-only scans
3. **Updates free space map** - Helps PostgreSQL find space for new rows
4. **Prevents transaction ID wraparound** - Critical for database stability (PostgreSQL uses 32-bit transaction IDs)

### VACUUM Types

| Type             | Description                                 | Locks              | Use Case              |
| ---------------- | ------------------------------------------- | ------------------ | --------------------- |
| `VACUUM`         | Marks space for reuse, doesn't return to OS | No exclusive lock  | Regular maintenance   |
| `VACUUM FULL`    | Rewrites entire table, returns space to OS  | **Exclusive lock** | Severe bloat recovery |
| `VACUUM ANALYZE` | Vacuums and updates planner statistics      | No exclusive lock  | After bulk changes    |

## Monitoring Vacuum Statistics

### Check Vacuum Status for All Tables

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
  n_mod_since_analyze as modifications_since_analyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 50;
```

**What to look for:**

- Tables with high `dead_tuples` count need attention
- Tables where `last_vacuum` and `last_autovacuum` are NULL or very old
- High `modifications_since_analyze` indicates stale statistics

### Check Current Autovacuum Settings

```sql
SELECT name, setting, unit, source, short_desc as description
FROM pg_settings
WHERE name IN (
  'autovacuum',
  'autovacuum_vacuum_threshold',
  'autovacuum_vacuum_insert_threshold',
  'autovacuum_analyze_threshold',
  'autovacuum_freeze_max_age',
  'track_counts'
);
```

### Monitor Autovacuum Progress in Real-Time

```sql
SELECT
  p.pid,
  now() - a.xact_start AS duration,
  coalesce(wait_event_type || '.' || wait_event, 'running') AS current_wait,
  p.relid::regclass as table_name,
  p.phase,
  p.heap_blks_total,
  p.heap_blks_scanned,
  p.heap_blks_vacuumed
FROM pg_stat_progress_vacuum p
JOIN pg_stat_activity a ON a.pid = p.pid;
```

## Autovacuum Thresholds

### Default Trigger Formula

Autovacuum triggers when:

```
dead tuples > autovacuum_vacuum_threshold + (autovacuum_vacuum_scale_factor * live tuples)
```

**Default values:**

- `autovacuum_vacuum_threshold` = 50
- `autovacuum_vacuum_scale_factor` = 0.2 (20%)

**Example:** A table with 1,000,000 rows triggers autovacuum when dead tuples exceed:

```
50 + (0.2 * 1,000,000) = 200,050 dead tuples
```

For large tables, this default can allow significant bloat before vacuum runs.

## Manual Vacuum Commands

### Standard Operations

```sql
-- Standard vacuum (marks space for reuse)
VACUUM table_name;

-- Verbose vacuum (shows detailed progress)
VACUUM (VERBOSE) table_name;

-- Vacuum and update statistics
VACUUM ANALYZE table_name;

-- Vacuum specific columns (updates column statistics only)
VACUUM ANALYZE table_name(column1, column2);
```

### Full Vacuum (Use with Caution)

```sql
-- Full vacuum - LOCKS TABLE EXCLUSIVELY
-- Only use during maintenance windows
VACUUM FULL table_name;
```

**Warning:** `VACUUM FULL` requires an exclusive lock on the table, blocking all reads and writes. It also requires additional disk space to write the new copy of the table.

## Table-Specific Autovacuum Settings

### Configure Aggressive Vacuum for High-Churn Tables

```sql
-- More aggressive vacuum for tables with frequent updates/deletes
ALTER TABLE high_churn_table SET (
  autovacuum_vacuum_scale_factor = 0.05,      -- 5% instead of 20%
  autovacuum_vacuum_threshold = 50,
  autovacuum_analyze_scale_factor = 0.02      -- Update stats more frequently
);
```

### Check Current Table Settings

```sql
SELECT relname, reloptions
FROM pg_class
WHERE relname = 'your_table';
```

### Reset to Default Settings

```sql
ALTER TABLE table_name RESET (
  autovacuum_vacuum_scale_factor,
  autovacuum_vacuum_threshold,
  autovacuum_analyze_scale_factor
);
```

## Troubleshooting Common Issues

### Issue 1: Vacuum Running Too Slowly

**Symptoms:** Autovacuum takes hours, dead tuples keep accumulating

**Solutions:**

```sql
-- Check current work memory
SHOW autovacuum_work_mem;

-- Increase for this session (requires superuser)
-- Or adjust in postgresql.conf
SET autovacuum_work_mem = '512MB';
```

Also consider:

- Increasing `autovacuum_max_workers` (default: 3)
- Lowering `autovacuum_vacuum_cost_delay` to make vacuum more aggressive

### Issue 2: Dead Tuples Accumulating Faster Than Vacuum

**Symptoms:** `n_dead_tup` keeps growing despite autovacuum running

**Solutions:**

1. Lower the scale factor for affected tables:

```sql
ALTER TABLE problem_table SET (
  autovacuum_vacuum_scale_factor = 0.01  -- 1% threshold
);
```

2. Increase autovacuum workers:

```sql
-- In postgresql.conf
autovacuum_max_workers = 5
```

### Issue 3: Table Bloat Despite Regular Vacuum

**Symptoms:** Table size much larger than actual data

**Diagnosis:**

```sql
-- Check table size vs estimated live data
SELECT
  pg_size_pretty(pg_total_relation_size('table_name')) as total_size,
  pg_size_pretty(pg_relation_size('table_name')) as table_size,
  n_live_tup,
  n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'table_name';
```

**Solution:** Schedule `VACUUM FULL` during maintenance window:

```sql
-- During low-traffic period
VACUUM FULL table_name;
```

### Issue 4: Transaction ID Wraparound Warnings

**Symptoms:** Log messages about transaction wraparound, aggressive autovacuum

**This is urgent!** PostgreSQL will shut down to prevent data corruption if not addressed.

**Check wraparound status:**

```sql
SELECT
  datname,
  age(datfrozenxid) as xid_age,
  current_setting('autovacuum_freeze_max_age')::bigint as freeze_max_age,
  current_setting('autovacuum_freeze_max_age')::bigint - age(datfrozenxid) as remaining
FROM pg_database
ORDER BY age(datfrozenxid) DESC;
```

**Emergency response:**

```sql
-- Run aggressive vacuum on affected tables
VACUUM FREEZE table_name;

-- Or vacuum entire database
VACUUMDB --all --freeze
```

## Best Practices

1. **Monitor regularly** - Set up alerts for tables with high dead tuple counts
2. **Tune per-table** - High-churn tables need lower scale factors
3. **Schedule maintenance windows** - For `VACUUM FULL` operations on bloated tables
4. **Don't disable autovacuum** - Unless you have a robust manual vacuum schedule
5. **Watch for wraparound** - Monitor transaction age and respond to warnings promptly
6. **Update statistics** - Use `VACUUM ANALYZE` after bulk operations

## Quick Reference

| Command               | Locks Table | Returns Space to OS | Updates Stats |
| --------------------- | ----------- | ------------------- | ------------- |
| `VACUUM`              | No          | No                  | No            |
| `VACUUM ANALYZE`      | No          | No                  | Yes           |
| `VACUUM FULL`         | **Yes**     | Yes                 | No            |
| `VACUUM FULL ANALYZE` | **Yes**     | Yes                 | Yes           |
| `VACUUM FREEZE`       | No          | No                  | No            |

## Verification

After vacuum operations, verify effectiveness:

```sql
-- Check dead tuples reduced
SELECT schemaname, relname, n_dead_tup, last_vacuum, last_autovacuum
FROM pg_stat_user_tables
WHERE relname = 'your_table';
```

## Maintenance Summary Template

After maintenance, provide a summary in this format:

```
## Vacuum Maintenance Summary

**Tables Processed:** [Count]

**Before/After:**
| Table | Dead Tuples Before | Dead Tuples After | Size Change |
|-------|-------------------|-------------------|-------------|
| [tbl] | [before]          | [after]           | [change]    |

**Autovacuum Settings Changed:**
- [Table]: [setting change]

**Issues Found:**
- [Any wraparound warnings or other issues]

**Recommendations:**
1. [Recommendation]
2. [Recommendation]
```
