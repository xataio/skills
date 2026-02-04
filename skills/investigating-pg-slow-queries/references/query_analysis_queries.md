# PostgreSQL Slow Query Investigation - SQL Reference

## Table of Contents

- [Finding Slow Queries](#finding-slow-queries)
- [Schema Investigation](#schema-investigation)
- [EXPLAIN Templates](#explain-templates)
- [Index Analysis](#index-analysis)
- [Index Creation Examples](#index-creation-examples)
- [Performance Diagnostics](#performance-diagnostics)

---

## Finding Slow Queries

### Basic pg_stat_statements Query

```sql
SELECT
  calls,
  round(max_exec_time/1000) max_exec_secs,
  round(mean_exec_time/1000) mean_exec_secs,
  round(total_exec_time/1000) total_exec_secs,
  query,
  queryid::text as queryid
FROM pg_stat_statements
WHERE max_exec_time > 2000
ORDER BY total_exec_time DESC
LIMIT 10;
```

### Detailed Statistics Including I/O

```sql
SELECT
  calls,
  round(max_exec_time/1000) max_exec_secs,
  round(mean_exec_time/1000) mean_exec_secs,
  round(total_exec_time/1000) total_exec_secs,
  rows,
  shared_blks_hit,
  shared_blks_read,
  round(100.0 * shared_blks_hit /
    nullif(shared_blks_hit + shared_blks_read, 0), 2) as cache_hit_pct,
  query,
  queryid::text as queryid
FROM pg_stat_statements
WHERE max_exec_time > 2000
ORDER BY total_exec_time DESC
LIMIT 10;
```

### Top Queries by Total Time (Any Duration)

```sql
SELECT
  calls,
  round(total_exec_time/1000) total_exec_secs,
  round(mean_exec_time) mean_exec_ms,
  round(100.0 * total_exec_time / sum(total_exec_time) over(), 2) as pct_total,
  query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

## Schema Investigation

### Find Table Schema

```sql
SELECT schemaname as schema
FROM pg_tables
WHERE tablename = 'your_table_name'
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC
LIMIT 1;
```

### Get Table Columns

```sql
SELECT
  column_name,
  data_type,
  is_nullable,
  column_default,
  character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'your_table'
ORDER BY ordinal_position;
```

### Get Table Indexes

```sql
SELECT
  i.relname as index_name,
  array_to_string(array_agg(a.attname ORDER BY k.i), ', ') as column_names,
  ix.indisunique as is_unique,
  ix.indisprimary as is_primary,
  pg_relation_size(i.oid) as index_size_bytes
FROM pg_class t, pg_class i, pg_index ix, pg_attribute a,
     generate_subscripts(ix.indkey, 1) k(i)
WHERE t.oid = ix.indrelid AND i.oid = ix.indexrelid
  AND a.attrelid = t.oid AND a.attnum = ix.indkey[k.i]
  AND t.relkind = 'r' AND t.relname = 'your_table'
GROUP BY i.relname, ix.indisunique, ix.indisprimary, i.oid;
```

### Table Size Information

```sql
SELECT
  pg_size_pretty(pg_total_relation_size('schema.table')) as total_size,
  pg_size_pretty(pg_table_size('schema.table')) as table_size,
  pg_size_pretty(pg_indexes_size('schema.table')) as indexes_size,
  (SELECT reltuples::bigint FROM pg_class WHERE relname = 'table') as estimated_rows;
```

## EXPLAIN Templates

### Safe EXPLAIN with Timeouts

```sql
BEGIN;
SET LOCAL statement_timeout = '2000ms';
SET LOCAL lock_timeout = '200ms';
SET search_path TO your_schema;

EXPLAIN (FORMAT TEXT) SELECT * FROM your_table WHERE column = 'value';

ROLLBACK;
```

### EXPLAIN for Parameterized Queries

```sql
BEGIN;
SET LOCAL statement_timeout = '2000ms';
SET LOCAL lock_timeout = '200ms';
SET search_path TO your_schema;

EXPLAIN (GENERIC_PLAN true) SELECT * FROM your_table WHERE column = $1;

ROLLBACK;
```

### EXPLAIN ANALYZE (Caution: Executes Query)

```sql
BEGIN;
SET LOCAL statement_timeout = '2000ms';
SET LOCAL lock_timeout = '200ms';
SET search_path TO your_schema;

EXPLAIN (ANALYZE true, BUFFERS true, FORMAT TEXT)
SELECT * FROM your_table WHERE column = 'value';

ROLLBACK;
```

### EXPLAIN with JSON Output (for programmatic analysis)

```sql
EXPLAIN (FORMAT JSON, ANALYZE true, BUFFERS true)
SELECT * FROM your_table WHERE column = 'value';
```

## Index Analysis

### Find Unused Indexes

```sql
SELECT
  schemaname || '.' || relname as table,
  indexrelname as index,
  pg_size_pretty(pg_relation_size(i.indexrelid)) as index_size,
  idx_scan as index_scans
FROM pg_stat_user_indexes i
JOIN pg_index USING (indexrelid)
WHERE idx_scan < 50
  AND indisunique IS FALSE
ORDER BY pg_relation_size(i.indexrelid) DESC;
```

### Find Missing Indexes (Tables with Sequential Scans)

```sql
SELECT
  schemaname || '.' || relname as table,
  seq_scan,
  seq_tup_read,
  idx_scan,
  n_live_tup as estimated_rows,
  pg_size_pretty(pg_relation_size(relid)) as table_size
FROM pg_stat_user_tables
WHERE seq_scan > 0
  AND n_live_tup > 10000
ORDER BY seq_tup_read DESC
LIMIT 20;
```

### Index Usage Statistics

```sql
SELECT
  t.relname as table_name,
  i.relname as index_name,
  pg_size_pretty(pg_relation_size(i.oid)) as index_size,
  idx.idx_scan as scans,
  idx.idx_tup_read as tuples_read,
  idx.idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes idx
JOIN pg_class t ON idx.relid = t.oid
JOIN pg_class i ON idx.indexrelid = i.oid
WHERE t.relname = 'your_table'
ORDER BY idx.idx_scan DESC;
```

## Index Creation Examples

### B-tree Index (Default)

```sql
-- Single column
CREATE INDEX idx_users_email ON users(email);

-- Multi-column (composite)
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

-- Descending order
CREATE INDEX idx_posts_created_desc ON posts(created_at DESC);
```

### Partial Index

```sql
-- Index only active records
CREATE INDEX idx_users_email_active ON users(email) WHERE is_active = true;

-- Index only recent data
CREATE INDEX idx_logs_recent ON logs(created_at)
WHERE created_at > '2024-01-01';
```

### Covering Index

```sql
-- Include additional columns to enable index-only scans
CREATE INDEX idx_orders_user_covering ON orders(user_id)
INCLUDE (order_total, status, created_at);
```

### Text Search Indexes

```sql
-- For LIKE 'prefix%' queries
CREATE INDEX idx_users_name_pattern ON users(name text_pattern_ops);

-- For full-text search
CREATE INDEX idx_posts_content_fts ON posts USING GIN(to_tsvector('english', content));
```

### JSONB Indexes

```sql
-- GIN index for JSONB containment queries
CREATE INDEX idx_data_jsonb ON table_name USING GIN(data_column);

-- Expression index for specific JSONB key
CREATE INDEX idx_data_type ON table_name((data_column->>'type'));
```

## Performance Diagnostics

### Check Table Statistics Freshness

```sql
SELECT
  schemaname,
  relname,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze,
  n_live_tup,
  n_dead_tup
FROM pg_stat_user_tables
WHERE relname = 'your_table';
```

### Force Statistics Update

```sql
ANALYZE your_table;
```

### Check for Lock Contention

```sql
SELECT
  blocked_locks.pid AS blocked_pid,
  blocked_activity.usename AS blocked_user,
  blocking_locks.pid AS blocking_pid,
  blocking_activity.usename AS blocking_user,
  blocked_activity.query AS blocked_statement,
  blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```
