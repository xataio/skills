# Replication Troubleshooting

**Note:** SQL queries run remotely; log checks require server access.

## Replication Types

| Type                 | Use Case                        | Data Copied     | Cross-Version |
| -------------------- | ------------------------------- | --------------- | ------------- |
| Streaming (Physical) | HA, read replicas               | Entire cluster  | No            |
| Logical              | Selective replication, upgrades | Specific tables | Yes           |

## Check Status on Primary

```sql
SELECT client_addr, application_name, state, sync_state,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
       pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag,
       reply_time
FROM pg_stat_replication;
```

**Healthy:** `state = 'streaming'`, `lag_bytes = 0`

## Check Status on Replica

```sql
SELECT pg_is_in_recovery();  -- Should be true

SELECT status, received_lsn, latest_end_lsn,
       NOW() - pg_last_xact_replay_timestamp() AS replay_delay
FROM pg_stat_wal_receiver;
```

## Replication Slots

```sql
SELECT slot_name, slot_type, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS wal_retained
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC;
```

**Warning:** Inactive slots cause WAL accumulation!

## Common Issues

### High Replication Lag

**Causes:** Long queries on replica, network issues, replica under-provisioned

**Solutions:**

```sql
-- On replica: prevent conflicts
ALTER SYSTEM SET hot_standby_feedback = on;
SELECT pg_reload_conf();
```

### Replica Query Conflicts

**Error:** `canceling statement due to conflict with recovery`

```sql
-- On replica
ALTER SYSTEM SET max_standby_streaming_delay = '5min';
ALTER SYSTEM SET hot_standby_feedback = on;
SELECT pg_reload_conf();
```

### WAL Accumulation from Slots

```sql
-- Drop inactive slot (CAUTION: replica needs resync)
SELECT pg_drop_replication_slot('inactive_slot');

-- Limit WAL retention (PostgreSQL 13+)
ALTER SYSTEM SET max_slot_wal_keep_size = '10GB';
```

### Missing WAL Files

**Error:** `requested WAL segment has already been removed`

```sql
-- Use replication slots (prevents WAL removal)
SELECT pg_create_physical_replication_slot('replica1_slot');

-- Or increase retention
ALTER SYSTEM SET wal_keep_size = '2GB';
```

**Recovery:** Rebuild replica from fresh backup.

## Failover

### Planned Switchover

1. On primary: `CHECKPOINT;`
2. Verify replica caught up (lag = 0)
3. On replica: `SELECT pg_promote();`
4. Update application connections

### Emergency Failover

```bash
pg_ctl promote -D /var/lib/postgresql/data
```

### Post-Failover

```sql
SELECT pg_is_in_recovery();  -- Should be false on new primary
```

- Update connection strings
- Rebuild old primary as replica
- Update monitoring

## Logical Replication

### Check Publication (Primary)

```sql
SELECT * FROM pg_publication;
SELECT * FROM pg_publication_tables;
```

### Check Subscription (Replica)

```sql
SELECT subname, subenabled, subslotname FROM pg_subscription;
SELECT * FROM pg_stat_subscription;
```

### Refresh Subscription

```sql
ALTER SUBSCRIPTION sub_name REFRESH PUBLICATION;
```

## Key Settings

**Primary:**

```sql
SHOW wal_level;           -- Must be 'replica' or 'logical'
SHOW max_wal_senders;     -- Number of replicas + buffer
SHOW max_replication_slots;
```

**Replica:**

```sql
SHOW hot_standby;                  -- Must be 'on'
SHOW hot_standby_feedback;
SHOW max_standby_streaming_delay;
```
