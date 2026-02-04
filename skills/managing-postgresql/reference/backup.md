# Backup and Recovery

## Contents

- [Backup Types](#backup-types)
- [Logical Backup (pg_dump)](#logical-backup-pg_dump)
- [Restore](#restore)
- [Physical Backup (pg_basebackup)](#physical-backup-pg_basebackup)
- [Point-in-Time Recovery (PITR)](#point-in-time-recovery-pitr)
- [Check Archive Status](#check-archive-status)
- [Encrypted Backup](#encrypted-backup)
- [Backup Strategy](#backup-strategy)
- [Cloud Providers](#cloud-providers)

**Note:** Replace `<HOST>` and `<USER>` with actual values. pg_dump/pg_restore run remotely; PITR requires server access.

## Backup Types

| Type       | Tool          | Use Case                                           | Speed  |
| ---------- | ------------- | -------------------------------------------------- | ------ |
| Logical    | pg_dump       | Small-medium DBs, selective restore, cross-version | Slow   |
| Physical   | pg_basebackup | Large DBs, PITR, replication setup                 | Fast   |
| Continuous | WAL archiving | Point-in-time recovery                             | Medium |

## Logical Backup (pg_dump)

```bash
# Custom format (recommended)
pg_dump -h <HOST> -U <USER> -Fc -f backup.dump dbname

# With compression
pg_dump -h <HOST> -U <USER> -Fc -Z 9 -f backup.dump dbname

# Schema only
pg_dump -h <HOST> -U <USER> -Fc --schema-only -f schema.dump dbname

# Specific tables
pg_dump -h <HOST> -U <USER> -Fc -t table1 -t table2 -f tables.dump dbname

# Parallel (directory format)
pg_dump -h <HOST> -U <USER> -Fd -j 4 -f backup_dir/ dbname

# All databases
pg_dumpall -h <HOST> -U <USER> -f full_backup.sql
```

## Restore

```bash
# Restore custom format
pg_restore -h <HOST> -U <USER> -d dbname backup.dump

# To new database
createdb -h <HOST> -U <USER> newdb
pg_restore -h <HOST> -U <USER> -d newdb backup.dump

# Clean (drop existing objects first)
pg_restore -h <HOST> -U <USER> -d dbname --clean backup.dump

# Parallel restore
pg_restore -h <HOST> -U <USER> -d dbname -j 4 backup_dir/

# List contents
pg_restore -l backup.dump
```

## Physical Backup (pg_basebackup)

```bash
pg_basebackup -h <HOST> -U <REPLICATION_USER> -D /backup/base -Fp -Xs -P
```

Options: `-Fp` (plain), `-Ft` (tar), `-z` (compress), `-Xs` (stream WAL), `-P` (progress)

## Point-in-Time Recovery (PITR)

### 1. Configure WAL Archiving (postgresql.conf)

```
archive_mode = on
archive_command = 'cp %p /archive/wal/%f'
```

### 2. Take Base Backup

```bash
pg_basebackup -h <HOST> -U <REPLICATION_USER> -D /backup/base -Fp -Xs -P
```

### 3. Recover (PostgreSQL 12+)

```bash
# Stop PostgreSQL, restore base backup to data directory
touch /var/lib/postgresql/data/recovery.signal
```

Add to postgresql.conf:

```
restore_command = 'cp /archive/wal/%f %p'
recovery_target_time = 'YYYY-MM-DD HH:MM:SS'  -- e.g., '2024-01-15 14:30:00'
recovery_target_action = 'promote'
```

Start PostgreSQL - it replays WAL until target.

### Create Restore Points

```sql
SELECT pg_create_restore_point('before_migration');
```

## Check Archive Status

```sql
SELECT archived_count, failed_count, last_archived_wal, last_archived_time
FROM pg_stat_archiver;
```

## Encrypted Backup

```bash
pg_dump -h <HOST> -U <USER> -Fc dbname | gpg --encrypt -r backup@company.com > backup.dump.gpg
gpg --decrypt backup.dump.gpg | pg_restore -h <HOST> -U <USER> -d dbname
```

## Backup Strategy

| Type          | Frequency  | Retention |
| ------------- | ---------- | --------- |
| pg_dump       | Daily      | 7 days    |
| pg_basebackup | Weekly     | 4 weeks   |
| WAL archives  | Continuous | 7 days    |
| Monthly full  | Monthly    | 12 months |

## Cloud Providers

- **AWS RDS:** Automated backups (1-35 days), manual snapshots, export to S3
- **GCP Cloud SQL:** Automated backups, on-demand, export to Cloud Storage
- **Azure:** Automated backups with geo-redundancy, long-term retention
