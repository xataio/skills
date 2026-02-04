# Performance Tuning

## Contents

- [Check Current Settings](#check-current-settings)
- [Memory Settings](#memory-settings)
- [WAL Settings](#wal-settings)
- [I/O Settings](#io-settings)
- [Parallelism](#parallelism-8-cores)
- [Apply Changes](#apply-changes)
- [Check Pending Restarts](#check-pending-restarts)
- [Autovacuum Tuning](#autovacuum-tuning)
- [Quick Reference](#quick-reference-16gb--8-cpu--ssd)
- [Troubleshooting](#troubleshooting)

**Always test changes in non-production first.**

## Check Current Settings

```sql
SELECT name, setting, unit, source
FROM pg_settings
WHERE name IN ('max_connections', 'shared_buffers', 'work_mem',
               'maintenance_work_mem', 'effective_cache_size',
               'wal_buffers', 'checkpoint_completion_target',
               'random_page_cost', 'effective_io_concurrency');
```

## Memory Settings

| Parameter              | Formula                                        | Typical Range |
| ---------------------- | ---------------------------------------------- | ------------- |
| `shared_buffers`       | 25% of RAM                                     | 1GB - 8GB     |
| `effective_cache_size` | 75% of RAM                                     | 3GB - 24GB    |
| `work_mem`             | (RAM - shared_buffers) / (max_connections × 3) | 4MB - 256MB   |
| `maintenance_work_mem` | 5% of RAM                                      | 256MB - 2GB   |

**Example for 16GB RAM:**

```
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 40MB
maintenance_work_mem = 800MB
```

## WAL Settings

| Parameter                      | Recommended                      |
| ------------------------------ | -------------------------------- |
| `wal_buffers`                  | 64MB (or 3% of shared_buffers)   |
| `min_wal_size`                 | 1GB                              |
| `max_wal_size`                 | 4GB (up to 16GB for write-heavy) |
| `checkpoint_completion_target` | 0.9                              |

## I/O Settings

| Storage     | effective_io_concurrency | random_page_cost |
| ----------- | ------------------------ | ---------------- |
| SSD/NVMe    | 200                      | 1.1              |
| HDD         | 2                        | 4.0              |
| Cloud (EBS) | 200                      | 1.1              |

## Parallelism (8+ cores)

```
max_worker_processes = <num_cpus>
max_parallel_workers = <num_cpus>
max_parallel_workers_per_gather = <num_cpus / 2>
max_parallel_maintenance_workers = 4
```

## Apply Changes

```sql
-- Dynamic parameters (no restart)
ALTER SYSTEM SET work_mem = '64MB';
SELECT pg_reload_conf();

-- Static parameters (requires restart)
ALTER SYSTEM SET shared_buffers = '4GB';
-- Then restart PostgreSQL
```

## Check Pending Restarts

```sql
SELECT name, setting, pending_restart
FROM pg_settings WHERE pending_restart = true;
```

## Autovacuum Tuning

```sql
-- Recommended for most workloads
ALTER SYSTEM SET autovacuum_vacuum_scale_factor = 0.1;     -- 10%
ALTER SYSTEM SET autovacuum_analyze_scale_factor = 0.05;   -- 5%

-- For large tables, set per-table
ALTER TABLE large_table SET (
    autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_analyze_scale_factor = 0.005
);
```

## Quick Reference: 16GB / 8 CPU / SSD

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

# I/O
effective_io_concurrency = 200
random_page_cost = 1.1

# Other
default_statistics_target = 100
huge_pages = try
```

## Troubleshooting

| Problem               | Solution                                                      |
| --------------------- | ------------------------------------------------------------- |
| High memory usage     | Reduce shared_buffers or work_mem                             |
| Slow queries          | Increase work_mem, effective_cache_size, enable parallelism   |
| Checkpoint spikes     | Increase max_wal_size, set checkpoint_completion_target = 0.9 |
| Vacuum falling behind | Increase autovacuum_max_workers, reduce scale_factor          |
