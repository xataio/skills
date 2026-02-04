# Security and Access Control

## Contents

- [Audit Roles](#audit-roles)
- [Create Roles](#create-roles)
- [Modify Roles](#modify-roles)
- [Drop Roles](#drop-roles)
- [pg_hba.conf](#pg_hbaconf)
- [SSL/TLS](#ssltls)
- [Object Permissions](#object-permissions)
- [Column-Level Permissions](#column-level-permissions)
- [Row-Level Security (RLS)](#row-level-security-rls)
- [Audit Logging](#audit-logging-postgresqlconf)
- [Security Checklist](#security-checklist)

**Note:** SQL queries run remotely; pg_hba.conf/SSL require server access or cloud console.

## Audit Roles

```sql
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin, rolreplication
FROM pg_roles ORDER BY rolname;
```

## Create Roles

```sql
-- Login user
CREATE ROLE app_user WITH LOGIN PASSWORD 'secure_password'
    CONNECTION LIMIT 10 VALID UNTIL '2025-12-31';

-- Group role (no login)
CREATE ROLE app_readers NOLOGIN;
CREATE ROLE app_writers NOLOGIN;

-- Add user to group
GRANT app_readers TO app_user;
```

## Modify Roles

```sql
ALTER ROLE app_user WITH PASSWORD 'new_password';
ALTER ROLE app_user VALID UNTIL '2025-06-30';
ALTER ROLE risky_admin NOSUPERUSER;
ALTER ROLE app_user CONNECTION LIMIT 5;
```

## Drop Roles

```sql
REASSIGN OWNED BY old_user TO new_owner;
DROP OWNED BY old_user;
DROP ROLE old_user;
```

## pg_hba.conf

Location: `SHOW hba_file;`

```sql
SELECT * FROM pg_hba_file_rules;  -- PostgreSQL 10+
```

### Recommended Configuration

```
# Local: peer for postgres, password for others
local   all   postgres                    peer
local   all   all                         scram-sha-256

# Localhost
host    all   all   127.0.0.1/32          scram-sha-256
host    all   all   ::1/128               scram-sha-256

# Internal network: require SSL
hostssl all   all   10.0.0.0/8            scram-sha-256

# Replication
hostssl replication repl_user 10.0.0.0/8  scram-sha-256

# Reject everything else
host    all   all   0.0.0.0/0             reject
```

### Authentication Methods

| Method          | Security  | Notes                     |
| --------------- | --------- | ------------------------- |
| `scram-sha-256` | **Best**  | PostgreSQL 10+            |
| `md5`           | Good      | Legacy                    |
| `cert`          | **Best**  | Client certificates       |
| `peer`          | Good      | Local only, OS user match |
| `password`      | **Avoid** | Cleartext                 |

## SSL/TLS

```sql
SHOW ssl;
SELECT pid, usename, ssl, version, cipher FROM pg_stat_ssl JOIN pg_stat_activity USING (pid);
```

### Force SSL (pg_hba.conf)

```
hostssl all all 0.0.0.0/0 scram-sha-256
```

## Object Permissions

```sql
-- Schema access
GRANT USAGE ON SCHEMA public TO app_readers;

-- Read-only
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readers;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_readers;

-- Read-write
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_writers;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_writers;

-- Revoke public access (recommended)
REVOKE ALL ON SCHEMA public FROM PUBLIC;
```

## Column-Level Permissions

```sql
GRANT SELECT (id, name, email) ON users TO support_role;
```

## Row-Level Security (RLS)

```sql
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Users see only their data
CREATE POLICY orders_user_policy ON orders
    FOR ALL USING (user_id = current_setting('app.user_id')::int);

-- Admins see all
CREATE POLICY orders_admin_policy ON orders
    FOR ALL TO admin_role USING (true);
```

Set context in application:

```sql
SET app.user_id = '123';
```

## Audit Logging (postgresql.conf)

```
log_connections = on
log_disconnections = on
log_statement = 'ddl'  -- or 'mod' or 'all'
log_min_duration_statement = 1000
```

## Security Checklist

- [ ] No empty passwords
- [ ] Password expiration configured
- [ ] scram-sha-256 authentication
- [ ] pg_hba.conf restricts access
- [ ] SSL required for remote connections
- [ ] Superusers limited
- [ ] Application uses non-superuser account
- [ ] PUBLIC privileges revoked
- [ ] Connection logging enabled
