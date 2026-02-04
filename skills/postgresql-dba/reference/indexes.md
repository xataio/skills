# Index Management

## Index Overview

```sql
SELECT schemaname || '.' || relname AS table_name, indexrelname AS index,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size,
       idx_scan AS scans, idx_tup_read AS rows_read
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC LIMIT 20;
```

## Find Unused Indexes

```sql
SELECT schemaname || '.' || relname AS table_name, indexrelname AS index,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size, idx_scan
FROM pg_stat_user_indexes i
JOIN pg_index USING (indexrelid)
WHERE NOT indisunique AND NOT indisprimary  -- Exclude constraints
  AND idx_scan < 50
ORDER BY pg_relation_size(indexrelid) DESC;
```

**Note:** Check how long stats have been accumulating: `SELECT stats_reset FROM pg_stat_bgwriter;`

## Find Missing Indexes

```sql
-- Tables with high sequential scans
SELECT schemaname || '.' || relname AS table_name,
       seq_scan, idx_scan,
       CASE WHEN (seq_scan + idx_scan) > 0
            THEN round(100.0 * seq_scan / (seq_scan + idx_scan), 2)
            ELSE 0 END AS seq_scan_pct,
       n_live_tup AS rows
FROM pg_stat_user_tables
WHERE n_live_tup > 10000 AND seq_scan > idx_scan
ORDER BY seq_scan DESC LIMIT 20;
```

## Index Bloat (requires pgstattuple)

```sql
SELECT indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size,
       (pgstatindex(indexrelid)).avg_leaf_density AS density,
       (pgstatindex(indexrelid)).leaf_fragmentation AS fragmentation
FROM pg_stat_user_indexes
WHERE pg_relation_size(indexrelid) > 10485760  -- > 10MB
ORDER BY (pgstatindex(indexrelid)).leaf_fragmentation DESC LIMIT 20;
```

| Metric             | Healthy | Warning | Critical |
| ------------------ | ------- | ------- | -------- |
| avg_leaf_density   | > 70%   | 50-70%  | < 50%    |
| leaf_fragmentation | < 20%   | 20-50%  | > 50%    |

## Create Indexes

```sql
-- Standard B-tree (non-blocking)
CREATE INDEX CONCURRENTLY idx_table_col ON table_name(column);

-- Composite (equality first, then range)
CREATE INDEX CONCURRENTLY idx_multi ON orders(user_id, created_at);

-- Partial (smaller, faster)
CREATE INDEX CONCURRENTLY idx_active ON orders(created_at) WHERE status = 'active';

-- Covering (enables index-only scans)
CREATE INDEX CONCURRENTLY idx_cover ON orders(user_id) INCLUDE (total, status);

-- Expression
CREATE INDEX CONCURRENTLY idx_lower ON users(LOWER(email));

-- GIN for JSONB
CREATE INDEX CONCURRENTLY idx_data ON events USING GIN(data);

-- BRIN for time-series (very compact)
CREATE INDEX CONCURRENTLY idx_logs ON logs USING BRIN(created_at);
```

## Rebuild Indexes

```sql
-- PostgreSQL 12+ non-blocking
REINDEX INDEX CONCURRENTLY bloated_index;
REINDEX TABLE CONCURRENTLY table_name;

-- Manual rebuild (if CONCURRENTLY fails)
CREATE INDEX CONCURRENTLY idx_new ON table(col);
DROP INDEX CONCURRENTLY idx_old;
ALTER INDEX idx_new RENAME TO idx_old;
```

## Drop Indexes

```sql
DROP INDEX CONCURRENTLY unused_index;
```

## Index Strategy Tips

1. **Column order matters** - Equality columns first, then range
2. **Always index foreign keys** - Prevents full table locks on parent DELETE
3. **Use partial indexes** - When queries frequently filter on same condition
4. **Use covering indexes** - Add INCLUDE columns for index-only scans
5. **Index size > table size** - Usually means over-indexing

## Why Index Not Used?

1. **Stale statistics** → `ANALYZE table_name`
2. **Low selectivity** → Planner chooses seq scan
3. **Type mismatch** → `WHERE id = '123'` won't use int index
4. **Function on column** → `WHERE DATE(created_at) = ...` needs expression index

## Find Invalid Indexes

```sql
SELECT schemaname || '.' || relname, indexrelname
FROM pg_stat_user_indexes
JOIN pg_index ON indexrelid = pg_index.indexrelid
WHERE NOT indisvalid;
```

Fix by dropping and recreating.
