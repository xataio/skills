# Disk Space Investigation

## Contents

- [Database Sizes](#database-sizes)
- [Largest Tables](#largest-tables)
- [Largest Indexes](#largest-indexes)
- [WAL Retention (Replication Slots)](#wal-retention-replication-slots)
- [Bloat Check](#bloat-check)
- [Reclaim Space](#reclaim-space)
- [Emergency: Disk Almost Full](#emergency-disk-almost-full)
- [Prevent Future Issues](#prevent-future-issues)
- [Partition Tables for Easy Cleanup](#partition-tables-for-easy-cleanup)

**Note:** SQL queries run remotely; filesystem checks need server access or cloud tools.

## Database Sizes

```sql
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;
```

## Largest Tables

```sql
SELECT
    schemaname || '.' || relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total,
    pg_size_pretty(pg_relation_size(relid)) AS table,
    pg_size_pretty(pg_indexes_size(relid)) AS indexes,
    n_dead_tup AS dead_tuples
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC LIMIT 20;
```

## Largest Indexes

```sql
SELECT schemaname || '.' || relname AS table, indexrelname AS index,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size, idx_scan
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC LIMIT 20;
```

## WAL Retention (Replication Slots)

```sql
SELECT slot_name, slot_type, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS wal_retained
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC;
```

## Bloat Check

```sql
SELECT schemaname || '.' || relname AS table,
       n_dead_tup, n_live_tup,
       CASE WHEN n_live_tup > 0 THEN round(100.0 * n_dead_tup / n_live_tup, 2) ELSE 0 END AS dead_pct,
       pg_size_pretty(pg_relation_size(relid)) AS size
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC LIMIT 20;
```

## Reclaim Space

### VACUUM (marks space for reuse, non-blocking)

```sql
VACUUM table_name;
VACUUM ANALYZE table_name;  -- Also updates statistics
```

### VACUUM FULL (returns space to OS, **blocks table**)

```sql
-- Only during maintenance window
VACUUM FULL table_name;
```

### pg_repack (non-blocking alternative)

```bash
pg_repack -h <HOST> -U <USER> -d dbname -t table_name
```

### Drop Unused Indexes

```sql
DROP INDEX CONCURRENTLY unused_index;
```

### Remove Inactive Replication Slots

```sql
-- CAUTION: Replica will need resync
SELECT pg_drop_replication_slot('inactive_slot');
```

### Delete Old Data

```sql
-- Delete in batches to avoid long locks
DELETE FROM logs WHERE created_at < NOW() - INTERVAL '90 days' LIMIT 10000;
-- Repeat, then VACUUM
```

## Emergency: Disk Almost Full

1. **Drop inactive replication slots** (immediate relief)
2. **TRUNCATE low-priority tables** (e.g., debug_logs)
3. **Drop unused indexes**
4. **Kill long-running transactions** (may be preventing VACUUM)

## Prevent Future Issues

```sql
-- Limit WAL retention by slots (PostgreSQL 13+)
ALTER SYSTEM SET max_slot_wal_keep_size = '10GB';

-- More aggressive vacuum for large tables
ALTER TABLE large_table SET (autovacuum_vacuum_scale_factor = 0.01);

SELECT pg_reload_conf();
```

## Partition Tables for Easy Cleanup

For time-series data, partition by date:

```sql
CREATE TABLE logs (...) PARTITION BY RANGE (created_at);

-- Drop old partitions instantly
DROP TABLE logs_2023_q1;
```
