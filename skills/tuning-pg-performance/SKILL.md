---
name: tuning-pg-performance
description: PostgreSQL performance tuning and configuration optimization. Use when asked to tune PostgreSQL, optimize database parameters, configure performance parameters, adjust memory parameters, optimize WAL configuration, tune parallelism, configure vacuum parameters, or review database configuration for performance.
---

# PostgreSQL Performance Tuning

## Prerequisites

**Required PostgreSQL version:** 9.6+ (some parallelism features require 10+)

**Optional extensions:**

- `pg_stat_statements` - Recommended for query analysis. Enable with:
  ```sql
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  ```

**Note:** All parameter recommendations in this skill are guidelines based on common workloads. Always test changes in a non-production environment first.

## Important Caveats

**ALWAYS test configuration changes in a non-production environment first.** Wrong settings can cause:
- Out-of-memory errors (OOM killer)
- Performance degradation instead of improvement
- Database crashes or instability

Monitor the database closely after any changes and be prepared to revert.

## Tuning Workflow

**Progress Checklist:**

```
- [ ] Step 1: Gather system information
- [ ] Step 2: Query current parameters
- [ ] Step 3: Calculate ideal parameters
- [ ] Step 4: Compare and report
- [ ] Apply changes (reload or restart as needed)
- [ ] Verify: Confirm parameters applied
```

### Step 1: Gather System Information

Collect cluster/instance information to understand available resources:

**Essential Information Needed:**

- Instance type (if cloud-hosted)
- CPU cores available
- Total RAM
- Storage type (SSD vs HDD)
- Cloud provider (AWS RDS, Aurora, GCP Cloud SQL, or self-hosted)

**Get Table Statistics:**

```sql
SELECT
    schemaname,
    relname as table_name,
    pg_size_pretty(pg_total_relation_size(relid)) as total_size,
    n_live_tup as row_count,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;
```

### Step 2: Query Current Settings

**Performance Settings:**

```sql
SELECT name, setting, unit, source, short_desc as description
FROM pg_settings
WHERE name IN (
  'max_connections',
  'work_mem',
  'shared_buffers',
  'maintenance_work_mem',
  'lock_timeout',
  'idle_in_transaction_session_timeout',
  'checkpoint_completion_target',
  'idle_session_timeout',
  'default_transaction_isolation',
  'max_wal_size',
  'log_min_duration_statement',
  'effective_cache_size',
  'wal_buffers',
  'effective_io_concurrency',
  'random_page_cost',
  'seq_page_cost',
  'huge_pages'
);
```

**Vacuum Settings:**

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

**Parallelism Settings:**

```sql
SELECT name, setting, unit, source, short_desc as description
FROM pg_settings
WHERE name IN (
  'max_worker_processes',
  'max_parallel_workers',
  'max_parallel_workers_per_gather',
  'max_parallel_maintenance_workers'
);
```

### Step 3: Calculate Ideal Settings

Use the Parameter Tuning Guidelines (see References section) to calculate optimal values based on:

- Available RAM
- Number of CPU cores
- Storage type (SSD/HDD)
- Expected connection count
- Workload type (OLTP vs OLAP)

### Step 4: Compare and Report

1. Compare calculated ideal values with current parameters
2. Identify parameters that need changes
3. Prioritize changes by impact:
   - **High Impact:** shared_buffers, effective_cache_size, work_mem
   - **Medium Impact:** WAL parameters, parallelism parameters
   - **Lower Impact:** Fine-tuning parameters

4. Report findings in structured format:

   ```
   | Parameter | Current | Recommended | Reason |
   |-----------|---------|-------------|--------|
   | shared_buffers | 128MB | 4GB | Set to 25% of 16GB RAM |
   ```

5. Note any parameters requiring restart vs reload
6. Include cloud-provider-specific instructions if applicable

## Parameter Tuning Guidelines

### Memory Settings

| Parameter              | Formula                                         | Typical Range | Notes                    |
| ---------------------- | ----------------------------------------------- | ------------- | ------------------------ |
| `shared_buffers`       | 25% of RAM                                      | 1GB - 8GB     | Main buffer cache        |
| `effective_cache_size` | 75% of RAM                                      | 3GB - 24GB    | Query planner hint       |
| `work_mem`             | (RAM - shared_buffers) / (max_connections \* 3) | 4MB - 256MB   | Per-operation memory     |
| `maintenance_work_mem` | 5% of RAM                                       | 256MB - 2GB   | For VACUUM, CREATE INDEX |

**Example for 16GB RAM system:**

```
shared_buffers = 4GB           # 25% of 16GB
effective_cache_size = 12GB    # 75% of 16GB
work_mem = 40MB                # (16GB - 4GB) / (100 connections * 3)
maintenance_work_mem = 800MB   # 5% of 16GB
```

### WAL Settings

| Parameter                      | Recommended | Notes                                           |
| ------------------------------ | ----------- | ----------------------------------------------- |
| `wal_buffers`                  | 64MB        | Or 3% of shared_buffers, whichever is larger    |
| `min_wal_size`                 | 1GB         | Minimum WAL space to retain                     |
| `max_wal_size`                 | 4GB         | Increase for write-heavy workloads (up to 16GB) |
| `checkpoint_completion_target` | 0.9         | Spread checkpoint I/O                           |

### Parallelism Settings (8+ core systems)

| Parameter                          | Formula        | Notes                             |
| ---------------------------------- | -------------- | --------------------------------- |
| `max_worker_processes`             | Number of CPUs | Background worker limit           |
| `max_parallel_workers`             | Number of CPUs | Total parallel workers            |
| `max_parallel_workers_per_gather`  | CPU / 2        | Per-query parallel workers        |
| `max_parallel_maintenance_workers` | 4              | For parallel CREATE INDEX, VACUUM |

**Example for 16-core system:**

```
max_worker_processes = 16
max_parallel_workers = 16
max_parallel_workers_per_gather = 8
max_parallel_maintenance_workers = 4
```

### I/O Settings

| Storage Type      | effective_io_concurrency | random_page_cost |
| ----------------- | ------------------------ | ---------------- |
| SSD / NVMe        | 200                      | 1.1              |
| HDD               | 2                        | 4.0              |
| Cloud (EBS, etc.) | 200                      | 1.1              |

### Other Important Settings

| Parameter                   | Recommended       | Notes                                           |
| --------------------------- | ----------------- | ----------------------------------------------- |
| `default_statistics_target` | 100 - 500         | Higher for complex queries, more accurate plans |
| `huge_pages`                | try               | Enable for large shared_buffers (>= 8GB)        |
| `max_connections`           | Based on workload | Consider using connection pooler for >200       |

## Vacuum Tuning

### Autovacuum Best Practices

```sql
-- Recommended autovacuum parameters for most workloads
autovacuum = on
autovacuum_vacuum_threshold = 50
autovacuum_vacuum_insert_threshold = 1000
autovacuum_analyze_threshold = 50
autovacuum_vacuum_scale_factor = 0.1    -- 10% of table
autovacuum_analyze_scale_factor = 0.05  -- 5% of table
track_counts = on
```

### Per-Table Vacuum Settings

For large tables, consider reducing scale factors:

```sql
ALTER TABLE large_table SET (
  autovacuum_vacuum_scale_factor = 0.01,
  autovacuum_analyze_scale_factor = 0.005
);
```

## Cloud Provider Specifics

### AWS RDS / Aurora

- Changes made via **Parameter Groups**
- Some parameters require **reboot** (static), others apply immediately (dynamic)
- Aurora has different memory model - shared_buffers typically 75% of "buffer pool"
- Use `pg_stat_statements` extension for query analysis

**Checking Parameter Status:**

```sql
SELECT name, setting, pending_restart
FROM pg_settings
WHERE pending_restart = true;
```

### GCP Cloud SQL

- Configuration via **database flags**
- Some flags require **instance restart**
- Default flags are generally well-tuned for Cloud SQL
- Use Cloud SQL Insights for performance monitoring

### Self-Hosted / On-Premise

- Edit `postgresql.conf` directly
- Use `ALTER SYSTEM` for persistent changes:
  ```sql
  ALTER SYSTEM SET shared_buffers = '4GB';
  SELECT pg_reload_conf();  -- For dynamic parameters
  -- Restart required for static parameters
  ```

## Quick Reference Card

### For a typical 16GB RAM / 8 CPU / SSD system:

```
# Memory
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 64MB
maintenance_work_mem = 1GB

# WAL
wal_buffers = 64MB
min_wal_size = 1GB
max_wal_size = 4GB
checkpoint_completion_target = 0.9

# Parallelism
max_worker_processes = 8
max_parallel_workers = 8
max_parallel_workers_per_gather = 4
max_parallel_maintenance_workers = 4

# I/O (SSD)
effective_io_concurrency = 200
random_page_cost = 1.1

# Other
default_statistics_target = 100
huge_pages = try
```

## Troubleshooting

### High Memory Usage

- Reduce `shared_buffers` or `work_mem`
- Check for runaway queries with large sorts/hashes

### Slow Queries

- Increase `work_mem` for sort/hash operations
- Increase `effective_cache_size` for better query plans
- Enable parallel query parameters

### Checkpoint Spikes

- Increase `max_wal_size`
- Set `checkpoint_completion_target = 0.9`

### Vacuum Falling Behind

- Increase `autovacuum_max_workers`
- Reduce `autovacuum_vacuum_scale_factor` for large tables
- Increase `maintenance_work_mem`

## Verification

After applying changes, verify parameters are active:

```sql
-- Check for pending restarts
SELECT name, setting, pending_restart
FROM pg_settings
WHERE pending_restart = true;

-- Confirm new parameters
SELECT name, setting, unit
FROM pg_settings
WHERE name IN ('shared_buffers', 'work_mem', 'effective_cache_size');
```

## Tuning Summary Template

After tuning, provide a summary in this format:

```
## Performance Tuning Summary

**System Specs:** [RAM] / [CPUs] / [Storage Type]

**Changes Made:**

| Parameter | Previous | New | Restart Required |
|-----------|----------|-----|------------------|
| [param]   | [old]    | [new] | [Yes/No]       |

**Rationale:**
[Brief explanation of why these values were chosen]

**Expected Impact:**
[What improvements to expect]

**Next Steps:**
- [ ] Schedule restart if required
- [ ] Monitor performance after changes
- [ ] Re-evaluate in [timeframe]
```
