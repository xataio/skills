# Slow Query Investigation

## Find Slow Queries (requires pg_stat_statements)

```sql
SELECT
    calls,
    round(max_exec_time/1000, 2) AS max_secs,
    round(mean_exec_time/1000, 2) AS mean_secs,
    round(total_exec_time/1000) AS total_secs,
    rows,
    query
FROM pg_stat_statements
WHERE max_exec_time > 2000  -- > 2 seconds
ORDER BY total_exec_time DESC
LIMIT 20;
```

## Currently Running Queries

```sql
SELECT pid, state, NOW() - query_start AS duration,
       wait_event_type, wait_event, LEFT(query, 100) AS query
FROM pg_stat_activity
WHERE state = 'active' AND pid != pg_backend_pid()
ORDER BY duration DESC;
```

## Analyze Query Plan

```sql
-- Always wrap in transaction with timeouts for safety
BEGIN;
SET LOCAL statement_timeout = '5s';
SET LOCAL lock_timeout = '1s';

-- For queries with literal values
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM table WHERE column = 'value';

-- For parameterized queries (PostgreSQL 16+)
EXPLAIN (GENERIC_PLAN) SELECT * FROM table WHERE column = $1;

ROLLBACK;
```

## EXPLAIN Red Flags

| Pattern                              | Problem                    | Solution                           |
| ------------------------------------ | -------------------------- | ---------------------------------- |
| Seq Scan on large table              | Missing index              | Create index on filter columns     |
| High rows removed by filter          | Inefficient filter         | Add index, refine query            |
| Nested Loop with many rows           | Bad join                   | Check join conditions, add indexes |
| Sort with high cost                  | Missing index for ORDER BY | Create index matching sort order   |
| actual vs estimated rows differ 10x+ | Stale statistics           | Run `ANALYZE table_name`           |

## Fix Stale Statistics

```sql
-- Check when stats were updated
SELECT schemaname, relname, last_analyze, last_autoanalyze, n_mod_since_analyze
FROM pg_stat_user_tables WHERE relname = 'your_table';

-- Update statistics
ANALYZE your_table;

-- For large tables, increase sampling
ALTER TABLE your_table SET (autovacuum_analyze_scale_factor = 0.01);
```

## Index Recommendations

```sql
-- Standard B-tree
CREATE INDEX idx_table_column ON table_name(column);

-- Composite (equality columns first, then range)
CREATE INDEX idx_multi ON table_name(status, created_at);

-- Partial (for filtered queries)
CREATE INDEX idx_active ON table_name(column) WHERE status = 'active';

-- Covering (for index-only scans)
CREATE INDEX idx_cover ON table_name(filter_col) INCLUDE (select_col1, select_col2);

-- Non-blocking creation
CREATE INDEX CONCURRENTLY idx_name ON table_name(column);
```

## auto_explain for Production

Add to `postgresql.conf` for automatic plan logging:

```
shared_preload_libraries = 'pg_stat_statements,auto_explain'
auto_explain.log_min_duration = '1s'
auto_explain.log_analyze = true
auto_explain.log_buffers = true
```
