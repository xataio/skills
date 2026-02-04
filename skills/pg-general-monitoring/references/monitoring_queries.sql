-- PostgreSQL General Monitoring Queries
-- Reference collection for database health assessment

--------------------------------------------------------------------------------
-- CONNECTION STATISTICS
-- Monitor connection utilization and identify potential connection exhaustion
--------------------------------------------------------------------------------

-- Connection utilization overview
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

-- Detailed connection breakdown by state
SELECT
    state,
    count(*) AS connection_count,
    round(100.0 * count(*) / sum(count(*)) OVER (), 2) AS percentage
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY state
ORDER BY connection_count DESC;

-- Connections by application name
SELECT
    application_name,
    count(*) AS connections,
    sum(CASE WHEN state = 'active' THEN 1 ELSE 0 END) AS active,
    sum(CASE WHEN state = 'idle' THEN 1 ELSE 0 END) AS idle
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY application_name
ORDER BY connections DESC;

--------------------------------------------------------------------------------
-- SLOW QUERY ANALYSIS
-- Requires pg_stat_statements extension
--------------------------------------------------------------------------------

-- Top 10 queries by total execution time (> 2 seconds max)
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

-- Top queries by mean execution time
SELECT
    calls,
    round(mean_exec_time::numeric, 2) AS mean_exec_ms,
    round(total_exec_time::numeric, 2) AS total_exec_ms,
    round((100 * total_exec_time / sum(total_exec_time) OVER ())::numeric, 2) AS pct_total_time,
    query
FROM pg_stat_statements
WHERE calls > 10
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Queries with high buffer usage (potential memory pressure)
SELECT
    calls,
    round(shared_blks_hit::numeric / NULLIF(shared_blks_hit + shared_blks_read, 0) * 100, 2) AS cache_hit_pct,
    shared_blks_read,
    shared_blks_hit,
    query
FROM pg_stat_statements
WHERE calls > 100
ORDER BY shared_blks_read DESC
LIMIT 10;

--------------------------------------------------------------------------------
-- TABLE STATISTICS
-- Size, row counts, and access patterns
--------------------------------------------------------------------------------

-- Table sizes with access statistics
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

-- Tables with high sequential scan ratio (candidates for indexing)
SELECT
    schemaname,
    relname AS table_name,
    seq_scan,
    idx_scan,
    CASE
        WHEN idx_scan = 0 THEN 100
        ELSE round(100.0 * seq_scan / (seq_scan + idx_scan), 2)
    END AS seq_scan_pct,
    n_live_tup AS estimated_rows
FROM pg_stat_user_tables
WHERE seq_scan > 0
    AND n_live_tup > 1000
ORDER BY seq_scan_pct DESC, seq_scan DESC
LIMIT 20;

-- Table bloat estimate
SELECT
    schemaname,
    relname AS table_name,
    n_dead_tup,
    n_live_tup,
    CASE
        WHEN n_live_tup = 0 THEN 0
        ELSE round(100.0 * n_dead_tup / n_live_tup, 2)
    END AS dead_tuple_pct,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 20;

--------------------------------------------------------------------------------
-- INDEX STATISTICS
-- Index usage and health
--------------------------------------------------------------------------------

-- Unused indexes (candidates for removal)
SELECT
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
    AND indexrelid NOT IN (SELECT conindid FROM pg_constraint)
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;

-- Index hit rate
SELECT
    sum(idx_blks_hit) AS idx_hit,
    sum(idx_blks_read) AS idx_read,
    round(sum(idx_blks_hit)::numeric / NULLIF(sum(idx_blks_hit) + sum(idx_blks_read), 0) * 100, 2) AS idx_hit_rate
FROM pg_statio_user_indexes;

--------------------------------------------------------------------------------
-- CONFIGURATION SETTINGS
-- Important PostgreSQL parameters to monitor
--------------------------------------------------------------------------------

-- Key performance settings
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN (
    'max_connections',
    'shared_buffers',
    'work_mem',
    'effective_cache_size',
    'maintenance_work_mem',
    'checkpoint_completion_target',
    'wal_buffers',
    'default_statistics_target',
    'random_page_cost',
    'effective_io_concurrency'
)
ORDER BY name;

-- Memory-related settings
SELECT name, setting, unit,
    CASE
        WHEN unit = '8kB' THEN pg_size_pretty(setting::bigint * 8192)
        WHEN unit = 'kB' THEN pg_size_pretty(setting::bigint * 1024)
        WHEN unit = 'MB' THEN pg_size_pretty(setting::bigint * 1024 * 1024)
        ELSE setting || ' ' || COALESCE(unit, '')
    END AS human_readable
FROM pg_settings
WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size')
ORDER BY name;

--------------------------------------------------------------------------------
-- DATABASE HEALTH OVERVIEW
-- General health metrics
--------------------------------------------------------------------------------

-- Database size
SELECT
    datname,
    pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;

-- Cache hit ratio (should be > 99% for OLTP)
SELECT
    sum(heap_blks_hit) AS heap_hit,
    sum(heap_blks_read) AS heap_read,
    round(sum(heap_blks_hit)::numeric / NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100, 2) AS cache_hit_ratio
FROM pg_statio_user_tables;

-- Transaction statistics
SELECT
    xact_commit,
    xact_rollback,
    round(100.0 * xact_rollback / NULLIF(xact_commit + xact_rollback, 0), 2) AS rollback_pct,
    blks_read,
    blks_hit,
    round(100.0 * blks_hit / NULLIF(blks_read + blks_hit, 0), 2) AS cache_hit_pct
FROM pg_stat_database
WHERE datname = current_database();

-- Long-running queries (> 5 minutes)
SELECT
    pid,
    now() - pg_stat_activity.query_start AS duration,
    state,
    query
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
    AND state != 'idle'
ORDER BY duration DESC;

-- Lock monitoring
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
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
