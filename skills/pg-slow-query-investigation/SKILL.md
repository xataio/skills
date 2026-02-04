---
name: pg-slow-query-investigation
description: Investigate and optimize slow PostgreSQL queries. Use when users mention slow queries, query optimization, EXPLAIN analysis, index recommendations, pg_stat_statements analysis, query performance issues, or need help understanding execution plans.
---

# PostgreSQL Slow Query Investigation

## Overview

This skill guides systematic investigation of slow PostgreSQL queries using pg_stat_statements, EXPLAIN analysis, and index recommendations. It helps identify performance bottlenecks and provides actionable DDL for optimization.

## Investigation Workflow

Follow these steps in order to investigate slow queries:

### Step 1: Identify Slow Queries

Query pg_stat_statements to find queries exceeding the 2000ms threshold:

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

### Step 2: Select a Query to Investigate

Choose a query following these guidelines:
- **Prefer SELECT queries** - avoid UPDATE, DELETE, INSERT
- **Avoid introspection queries** - skip queries involving pg_catalog or information_schema
- **Consider total impact** - high call count with moderate latency may be worse than rare slow queries
- **Format the query** across multiple lines with no line longer than 80 characters

### Step 3: Understand the Table Structure

Find the schema and examine the table:

```sql
-- Find the schema
SELECT schemaname as schema
FROM pg_tables
WHERE tablename = 'your_table_name'
ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC
LIMIT 1;

-- Get column information
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'your_table'
ORDER BY ordinal_position;

-- Get existing indexes
SELECT
  i.relname as index_name,
  array_to_string(array_agg(a.attname ORDER BY k.i), ', ') as column_names,
  ix.indisunique as is_unique,
  ix.indisprimary as is_primary
FROM pg_class t, pg_class i, pg_index ix, pg_attribute a,
     generate_subscripts(ix.indkey, 1) k(i)
WHERE t.oid = ix.indrelid AND i.oid = ix.indexrelid
  AND a.attrelid = t.oid AND a.attnum = ix.indkey[k.i]
  AND t.relkind = 'r' AND t.relname = 'your_table'
GROUP BY i.relname, ix.indisunique, ix.indisprimary;
```

### Step 4: Analyze the Execution Plan

Run EXPLAIN with appropriate safety measures:

```sql
BEGIN;
SET LOCAL statement_timeout = '2000ms';
SET LOCAL lock_timeout = '200ms';
SET search_path TO your_schema;

-- For parameterized queries ($1, $2, etc.), use GENERIC_PLAN:
EXPLAIN (GENERIC_PLAN true) SELECT * FROM your_table WHERE column = $1;

-- For queries with literal values, use standard EXPLAIN:
EXPLAIN SELECT * FROM your_table WHERE column = 'value';

-- For actual runtime statistics (use with caution on production):
EXPLAIN ANALYZE SELECT * FROM your_table WHERE column = 'value';

ROLLBACK;
```

**Important:** Always wrap EXPLAIN in a transaction with timeouts to prevent blocking.

### Step 5: Recommend Index Improvements

Based on the execution plan, provide specific DDL if a missing index is identified.

## EXPLAIN Plan Interpretation

| Plan Node | Meaning | Action |
|-----------|---------|--------|
| **Seq Scan** | Full table scan | Likely needs an index on filter columns |
| **Index Scan** | Using index, fetching rows from table | Good, but check if index-only scan possible |
| **Index Only Scan** | Data retrieved from index alone | Optimal for the columns involved |
| **Bitmap Heap Scan** | Multiple index conditions combined | Generally efficient for OR conditions |
| **Nested Loop** | Row-by-row join | Can be slow for large datasets; check join conditions |
| **Hash Join** | Hash table built for join | Good for large table joins |
| **Merge Join** | Sorted merge of two inputs | Efficient when inputs are pre-sorted |
| **Sort** | Explicit sort operation | Consider index on ORDER BY columns |

### Red Flags to Watch For

- **Seq Scan on large tables** - Usually indicates missing index
- **High actual rows vs estimated rows** - Statistics may be stale (run ANALYZE)
- **Nested Loop with high row counts** - May need different join strategy
- **Sort with high memory/disk usage** - Consider index or increase work_mem

## Index Creation Patterns

```sql
-- Standard B-tree index (most common)
CREATE INDEX idx_table_column ON table_name(column1, column2);

-- Partial index for specific conditions (reduces index size)
CREATE INDEX idx_table_active ON table_name(column) WHERE is_active = true;

-- Covering index (enables index-only scans)
CREATE INDEX idx_table_covering ON table_name(column1) INCLUDE (column2, column3);

-- Index for LIKE queries with prefix matching
CREATE INDEX idx_table_text ON table_name(column text_pattern_ops);

-- GIN index for array or JSONB columns
CREATE INDEX idx_table_jsonb ON table_name USING GIN(jsonb_column);
```

### Index Selection Guidelines

1. **Column order matters** - Put equality conditions first, then range conditions
2. **Partial indexes** - Use when queries frequently filter on the same condition
3. **Covering indexes** - Add frequently selected columns via INCLUDE to avoid table lookups
4. **Composite indexes** - Combine columns often filtered together

## Summary Template

After investigation, provide a summary in this format:

```
## Slow Query Investigation Summary

**Query Identified:**
[The slow query, formatted]

**Performance Metrics:**
- Max execution time: X seconds
- Mean execution time: X seconds
- Total calls: X

**Root Cause:**
[Why the query is slow - e.g., "Sequential scan on large table due to missing index on column X"]

**Recommended Fix:**
[Exact DDL to create index or other optimization]

**Expected Improvement:**
[Estimate of improvement - e.g., "Expected to reduce query time from ~5s to <100ms by enabling index scan"]
```

## References

See `references/sql_queries.md` for complete SQL query templates and additional examples.
