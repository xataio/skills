# Vacuum and Table Maintenance

## Contents

- [Check Vacuum Status](#check-vacuum-status)
- [Monitor Running Vacuum](#monitor-running-vacuum)
- [Vacuum Commands](#vacuum-commands)
- [pg_repack (Non-Blocking Alternative)](#pg_repack-non-blocking-alternative-to-vacuum-full)
- [Autovacuum Tuning](#autovacuum-tuning)
- [Transaction ID Wraparound](#transaction-id-wraparound)
- [Troubleshooting](#troubleshooting)

## Check Vacuum Status

```sql
SELECT
    schemaname || '.' || relname AS table_name,
    n_dead_tup AS dead_tuples,
    n_live_tup AS live_tuples,
    CASE WHEN n_live_tup > 0 THEN round(100.0 * n_dead_tup / n_live_tup, 2) ELSE 0 END AS dead_pct,
    last_vacuum,
    last_autovacuum,
    n_mod_since_analyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 20;
```

## Monitor Running Vacuum

```sql
SELECT p.pid, p.relid::regclass AS table_name, p.phase,
       p.heap_blks_scanned, p.heap_blks_total,
       round(100.0 * p.heap_blks_scanned / nullif(p.heap_blks_total, 0), 1) AS pct_done
FROM pg_stat_progress_vacuum p;
```

## Vacuum Commands

| Command                | Locks   | Returns Space to OS | Use Case            |
| ---------------------- | ------- | ------------------- | ------------------- |
| `VACUUM table`         | No      | No                  | Regular maintenance |
| `VACUUM ANALYZE table` | No      | No                  | After bulk changes  |
| `VACUUM FULL table`    | **Yes** | Yes                 | Severe bloat only   |
| `VACUUM FREEZE table`  | No      | No                  | Prevent wraparound  |

```sql
-- Standard vacuum
VACUUM table_name;

-- Vacuum with verbose output
VACUUM (VERBOSE) table_name;

-- Vacuum and update statistics
VACUUM ANALYZE table_name;

-- Full vacuum (LOCKS TABLE - maintenance window only)
VACUUM FULL table_name;
```

## pg_repack (Non-Blocking Alternative to VACUUM FULL)

**Installation required:** pg_repack is not included with PostgreSQL. Install separately:

```bash
# Debian/Ubuntu
sudo apt-get install postgresql-<version>-repack

# RHEL/CentOS
sudo yum install pg_repack_<version>

# macOS (Homebrew)
brew install pg_repack
```

Then create the extension in your database:

```sql
CREATE EXTENSION pg_repack;
```

**Usage:**

```bash
pg_repack -h <HOST> -U <USER> -d database -t schema.table_name
```

## Autovacuum Tuning

### Check Current Settings

```sql
SELECT name, setting FROM pg_settings
WHERE name LIKE 'autovacuum%' OR name = 'track_counts';
```

### Autovacuum Trigger Formula

```
dead tuples > autovacuum_vacuum_threshold + (scale_factor × live tuples)
Default: 50 + (0.2 × live_tuples)
```

For a 1M row table: triggers at 200,050 dead tuples (20% bloat).

### Per-Table Aggressive Vacuum

```sql
-- For high-churn tables
ALTER TABLE high_churn_table SET (
    autovacuum_vacuum_scale_factor = 0.01,      -- 1% instead of 20%
    autovacuum_vacuum_threshold = 50,
    autovacuum_analyze_scale_factor = 0.005
);

-- Check table settings
SELECT relname, reloptions FROM pg_class WHERE relname = 'your_table';

-- Reset to defaults
ALTER TABLE table_name RESET (autovacuum_vacuum_scale_factor);
```

## Transaction ID Wraparound

**This is urgent!** PostgreSQL shuts down if not addressed.

```sql
-- Check wraparound risk
SELECT datname,
       age(datfrozenxid) AS xid_age,
       current_setting('autovacuum_freeze_max_age')::bigint AS freeze_max_age,
       current_setting('autovacuum_freeze_max_age')::bigint - age(datfrozenxid) AS remaining
FROM pg_database
ORDER BY age(datfrozenxid) DESC;
```

**Emergency response:**

```sql
VACUUM FREEZE table_name;
```

Or from command line:

```bash
vacuumdb -h <HOST> -U <USER> --all --freeze
```

## Troubleshooting

| Issue                      | Symptom                     | Solution                                                  |
| -------------------------- | --------------------------- | --------------------------------------------------------- |
| Vacuum too slow            | Takes hours                 | Increase `autovacuum_work_mem`, lower `vacuum_cost_delay` |
| Dead tuples growing        | n_dead_tup keeps increasing | Lower `autovacuum_vacuum_scale_factor`                    |
| Table bloat despite vacuum | Size >> data                | Use `VACUUM FULL` or pg_repack                            |
| Wraparound warnings        | Log warnings                | Run `VACUUM FREEZE` immediately                           |
