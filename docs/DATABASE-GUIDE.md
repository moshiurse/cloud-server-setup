# Database Guide — MySQL & PostgreSQL on VPS

> **Part of the [VPS Deployment Kit](../README.md)**
> Related: [Deployment Guide](../DEPLOYMENT-GUIDE.md) · [Cheatsheet](../CHEATSHEET.md) · [Nginx Configs](../nginx/) · [SSL Guide](../ssl/)

Complete guide to setting up, tuning, backing up, and managing MySQL and PostgreSQL on an Ubuntu 22.04 VPS.

---

## Table of Contents

1. [Choosing MySQL vs PostgreSQL](#1-choosing-mysql-vs-postgresql)
2. [MySQL Setup](#2-mysql-setup)
3. [PostgreSQL Setup](#3-postgresql-setup)
4. [Backup & Restore](#4-backup--restore)
5. [Database Management Commands](#5-database-management-commands)
6. [Database Migration Tips](#6-database-migration-tips)
7. [Troubleshooting](#7-troubleshooting)
8. [Security Best Practices](#8-security-best-practices)

---

## 1. Choosing MySQL vs PostgreSQL

| Feature | MySQL | PostgreSQL |
|---|---|---|
| **Best for** | Simple web apps, CMS (WordPress, Laravel) | Complex queries, analytics, geospatial |
| **JSON support** | Basic (`JSON` type) | Advanced (`jsonb`, indexable) |
| **Performance** | Faster for simple reads | Faster for complex joins/writes |
| **Replication** | Built-in, easy to set up | Streaming replication, more flexible |
| **Full-text search** | Basic built-in | Powerful built-in (`tsvector`) |
| **ACID compliance** | With InnoDB (default) | Fully ACID by default |
| **Ecosystem** | WordPress, Drupal, most PHP apps | Django, Rails, many Node.js ORMs |
| **Hosting support** | Nearly universal | Widely supported, growing fast |
| **Learning curve** | Easier for beginners | Slightly steeper, more standards-compliant |
| **License** | GPL (Oracle-owned) | PostgreSQL License (true open source) |

**Rule of thumb:**
- **Choose MySQL** if you're running WordPress, Laravel, or a standard LAMP/LEMP stack.
- **Choose PostgreSQL** if you need advanced data types, complex queries, or strict SQL compliance.

---

## 2. MySQL Setup

### 2.1 Install on Ubuntu 22.04

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install MySQL server
sudo apt install mysql-server -y

# Verify installation
sudo systemctl status mysql

# Check version
mysql --version
```

### 2.2 Secure Installation

```bash
# Run the security script
sudo mysql_secure_installation
```

You'll be prompted for:

| Prompt | Recommended Answer |
|---|---|
| VALIDATE PASSWORD component | `Y` — enable password validation |
| Password validation policy | `1` (MEDIUM) — requires length ≥ 8, mixed case, numbers, special chars |
| Remove anonymous users | `Y` |
| Disallow root login remotely | `Y` |
| Remove test database | `Y` |
| Reload privilege tables | `Y` |

```bash
# Set root password (if not set during secure installation)
sudo mysql
```

```sql
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'YourStrongRootPassword123!';
FLUSH PRIVILEGES;
EXIT;
```

```bash
# Verify you can log in
mysql -u root -p
```

### 2.3 Create Database and User

```bash
# Log in to MySQL as root
sudo mysql -u root -p
```

```sql
-- Create the database
CREATE DATABASE myapp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create a dedicated user (localhost only)
CREATE USER 'myapp_user'@'localhost' IDENTIFIED BY 'SecurePassword123!';

-- Verify database was created
SHOW DATABASES;

-- Verify user was created
SELECT user, host FROM mysql.user;
```

### 2.4 Grant Privileges

```sql
-- Grant all privileges on the app database only
GRANT ALL PRIVILEGES ON myapp_db.* TO 'myapp_user'@'localhost';

-- Apply the changes
FLUSH PRIVILEGES;

-- Verify grants
SHOW GRANTS FOR 'myapp_user'@'localhost';

EXIT;
```

```bash
# Test the new user
mysql -u myapp_user -p myapp_db
```

### 2.5 Connection Strings

**Node.js (mysql2)**
```js
// .env
DATABASE_URL="mysql://myapp_user:SecurePassword123!@localhost:3306/myapp_db"

// connection.js
const mysql = require('mysql2/promise');
const pool = mysql.createPool({
  host: 'localhost',
  port: 3306,
  user: 'myapp_user',
  password: 'SecurePassword123!',
  database: 'myapp_db',
  waitForConnections: true,
  connectionLimit: 10,
});
```

**PHP (PDO)**
```php
<?php
$dsn = 'mysql:host=localhost;port=3306;dbname=myapp_db;charset=utf8mb4';
$pdo = new PDO($dsn, 'myapp_user', 'SecurePassword123!', [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
]);
```

**Laravel (.env)**
```dotenv
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=myapp_db
DB_USERNAME=myapp_user
DB_PASSWORD=SecurePassword123!
```

**Python (PyMySQL / SQLAlchemy)**
```python
# PyMySQL
import pymysql
conn = pymysql.connect(
    host='localhost',
    port=3306,
    user='myapp_user',
    password='SecurePassword123!',
    database='myapp_db',
    charset='utf8mb4',
)

# SQLAlchemy
from sqlalchemy import create_engine
engine = create_engine('mysql+pymysql://myapp_user:SecurePassword123!@localhost:3306/myapp_db')
```

### 2.6 MySQL Config Tuning for VPS

Edit the MySQL config file:

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

**For 2GB RAM VPS:**

```ini
[mysqld]
# InnoDB settings — allocate ~50% of RAM to buffer pool
innodb_buffer_pool_size = 768M
innodb_log_file_size    = 128M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method     = O_DIRECT

# Connection limits
max_connections         = 100
wait_timeout            = 300
interactive_timeout     = 300

# Query cache (disabled in MySQL 8.0+, use for 5.7)
# query_cache_type      = 1
# query_cache_size      = 64M

# Temp tables
tmp_table_size          = 32M
max_heap_table_size     = 32M

# Logging slow queries
slow_query_log          = 1
slow_query_log_file     = /var/log/mysql/slow.log
long_query_time         = 2

# Character set
character-set-server    = utf8mb4
collation-server        = utf8mb4_unicode_ci
```

**For 4GB RAM VPS:**

```ini
[mysqld]
innodb_buffer_pool_size = 1536M
innodb_log_file_size    = 256M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method     = O_DIRECT

max_connections         = 200
wait_timeout            = 300
interactive_timeout     = 300

tmp_table_size          = 64M
max_heap_table_size     = 64M

slow_query_log          = 1
slow_query_log_file     = /var/log/mysql/slow.log
long_query_time         = 2

character-set-server    = utf8mb4
collation-server        = utf8mb4_unicode_ci
```

```bash
# Apply changes
sudo systemctl restart mysql

# Verify settings
mysql -u root -p -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';"
```

### 2.7 Remote Access Setup (If Needed)

> ⚠️ **Only enable remote access if you truly need it.** Prefer SSH tunnels or VPNs instead.

```bash
# Edit MySQL bind address
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```

```ini
# Change from:
bind-address = 127.0.0.1

# To (accept all interfaces):
bind-address = 0.0.0.0
```

```bash
# Create a user that can connect remotely
sudo mysql -u root -p
```

```sql
-- Allow from a specific IP only (recommended)
CREATE USER 'remote_user'@'203.0.113.50' IDENTIFIED BY 'StrongRemotePass123!';
GRANT ALL PRIVILEGES ON myapp_db.* TO 'remote_user'@'203.0.113.50';
FLUSH PRIVILEGES;
EXIT;
```

```bash
# Restart MySQL
sudo systemctl restart mysql

# Open firewall for the specific IP only
sudo ufw allow from 203.0.113.50 to any port 3306 comment "MySQL remote - trusted IP"

# Verify from the remote machine
mysql -h YOUR_VPS_IP -u remote_user -p myapp_db
```

---

## 3. PostgreSQL Setup

### 3.1 Install on Ubuntu 22.04

```bash
# Install PostgreSQL
sudo apt update && sudo apt install postgresql postgresql-contrib -y

# Verify it's running
sudo systemctl status postgresql

# Check version
psql --version
```

### 3.2 Create Database and User/Role

```bash
# Switch to the postgres system user
sudo -u postgres psql
```

```sql
-- Create a role (user) with a password
CREATE ROLE myapp_user WITH LOGIN PASSWORD 'SecurePassword123!';

-- Create the database owned by that role
CREATE DATABASE myapp_db OWNER myapp_user;

-- Verify
\l
\du

\q
```

```bash
# Test the connection
psql -U myapp_user -d myapp_db -h localhost
```

### 3.3 Grant Privileges

```bash
sudo -u postgres psql
```

```sql
-- Grant connect privilege
GRANT CONNECT ON DATABASE myapp_db TO myapp_user;

-- Connect to the database to set schema-level privileges
\c myapp_db

-- Grant usage and create on the public schema
GRANT USAGE, CREATE ON SCHEMA public TO myapp_user;

-- Grant all on all current tables (if any exist)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO myapp_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO myapp_user;

-- Auto-grant on future tables created by postgres role
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL PRIVILEGES ON TABLES TO myapp_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT ALL PRIVILEGES ON SEQUENCES TO myapp_user;

\q
```

### 3.4 Connection Strings

**Node.js (pg)**
```js
// .env
DATABASE_URL="postgresql://myapp_user:SecurePassword123!@localhost:5432/myapp_db"

// connection.js
const { Pool } = require('pg');
const pool = new Pool({
  host: 'localhost',
  port: 5432,
  user: 'myapp_user',
  password: 'SecurePassword123!',
  database: 'myapp_db',
  max: 20,
});
```

**PHP (PDO)**
```php
<?php
$dsn = 'pgsql:host=localhost;port=5432;dbname=myapp_db';
$pdo = new PDO($dsn, 'myapp_user', 'SecurePassword123!', [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
]);
```

**Laravel (.env)**
```dotenv
DB_CONNECTION=pgsql
DB_HOST=127.0.0.1
DB_PORT=5432
DB_DATABASE=myapp_db
DB_USERNAME=myapp_user
DB_PASSWORD=SecurePassword123!
```

**Python (psycopg2 / SQLAlchemy)**
```python
# psycopg2
import psycopg2
conn = psycopg2.connect(
    host='localhost',
    port=5432,
    user='myapp_user',
    password='SecurePassword123!',
    dbname='myapp_db',
)

# SQLAlchemy
from sqlalchemy import create_engine
engine = create_engine('postgresql+psycopg2://myapp_user:SecurePassword123!@localhost:5432/myapp_db')
```

### 3.5 PostgreSQL Config Tuning

Edit the main config:

```bash
# Find config file location
sudo -u postgres psql -c "SHOW config_file;"
# Usually: /etc/postgresql/14/main/postgresql.conf

sudo nano /etc/postgresql/14/main/postgresql.conf
```

**For 2GB RAM VPS:**

```ini
# Memory
shared_buffers          = 512MB      # ~25% of RAM
effective_cache_size    = 1536MB     # ~75% of RAM
work_mem                = 4MB        # Per-operation memory
maintenance_work_mem    = 128MB      # For VACUUM, CREATE INDEX

# Write-ahead log
wal_buffers             = 16MB
checkpoint_completion_target = 0.9
max_wal_size            = 1GB

# Connections
max_connections         = 100

# Planner
random_page_cost        = 1.1        # For SSD storage
effective_io_concurrency = 200       # For SSD storage

# Logging
log_min_duration_statement = 2000    # Log queries slower than 2s
log_statement           = 'none'
log_line_prefix         = '%t [%p] %u@%d '
```

**For 4GB RAM VPS:**

```ini
shared_buffers          = 1GB
effective_cache_size    = 3GB
work_mem                = 8MB
maintenance_work_mem    = 256MB

wal_buffers             = 16MB
checkpoint_completion_target = 0.9
max_wal_size            = 2GB

max_connections         = 200

random_page_cost        = 1.1
effective_io_concurrency = 200

log_min_duration_statement = 2000
log_statement           = 'none'
log_line_prefix         = '%t [%p] %u@%d '
```

```bash
# Apply changes
sudo systemctl restart postgresql

# Verify a setting
sudo -u postgres psql -c "SHOW shared_buffers;"
```

### 3.6 pg_hba.conf Explained

```bash
# Find the file
sudo -u postgres psql -c "SHOW hba_file;"
# Usually: /etc/postgresql/14/main/pg_hba.conf

sudo nano /etc/postgresql/14/main/pg_hba.conf
```

The file controls **who can connect, from where, and how they authenticate**:

```
# TYPE    DATABASE    USER          ADDRESS         METHOD
# ────    ────────    ────          ───────         ──────

# Local socket connections (unix domain socket)
local     all         postgres                      peer
local     all         all                           peer

# IPv4 local connections
host      all         all           127.0.0.1/32    scram-sha-256

# IPv6 local connections
host      all         all           ::1/128         scram-sha-256
```

| Field | Options | Description |
|---|---|---|
| **TYPE** | `local`, `host`, `hostssl` | Connection type (socket / TCP / TLS-only TCP) |
| **DATABASE** | `all`, `myapp_db` | Which database this rule applies to |
| **USER** | `all`, `myapp_user` | Which role/user this rule applies to |
| **ADDRESS** | `127.0.0.1/32`, `0.0.0.0/0` | IP range allowed (host/hostssl only) |
| **METHOD** | `peer`, `scram-sha-256`, `md5`, `reject` | Authentication method |

**Common methods:**
- `peer` — OS username must match DB role (local only)
- `scram-sha-256` — Password auth (recommended for TCP)
- `md5` — Older password auth (less secure than scram)
- `reject` — Block the connection

**Recommended production config:**

```
# App user: password auth, localhost only
host    myapp_db    myapp_user    127.0.0.1/32    scram-sha-256

# Admin: peer auth over socket (no password needed when sudoing to postgres)
local   all         postgres                      peer

# Block everything else
host    all         all           0.0.0.0/0       reject
```

```bash
# Reload after changes (no restart needed)
sudo systemctl reload postgresql
```

### 3.7 Remote Access Setup

> ⚠️ **Prefer SSH tunnels over direct remote access.**

```bash
# 1. Edit postgresql.conf to listen on all interfaces
sudo nano /etc/postgresql/14/main/postgresql.conf
```

```ini
# Change from:
#listen_addresses = 'localhost'

# To:
listen_addresses = '*'
```

```bash
# 2. Add a rule to pg_hba.conf for the remote IP
sudo nano /etc/postgresql/14/main/pg_hba.conf
```

```
# Allow a specific IP
host    myapp_db    myapp_user    203.0.113.50/32    scram-sha-256
```

```bash
# 3. Restart PostgreSQL
sudo systemctl restart postgresql

# 4. Open the firewall for that IP only
sudo ufw allow from 203.0.113.50 to any port 5432 comment "PostgreSQL remote - trusted IP"

# 5. Test from the remote machine
psql -h YOUR_VPS_IP -U myapp_user -d myapp_db
```

**Preferred alternative — SSH tunnel (no pg_hba / firewall changes needed):**

```bash
# From your local machine, create an SSH tunnel
ssh -L 5432:localhost:5432 deploy@YOUR_VPS_IP -N -f

# Then connect as if PostgreSQL were local
psql -h localhost -U myapp_user -d myapp_db
```

---

## 4. Backup & Restore

### 4.1 MySQL Backup & Restore

**Manual backup:**

```bash
# Dump a single database
mysqldump -u myapp_user -p myapp_db > myapp_db_backup.sql

# Dump with compression
mysqldump -u myapp_user -p myapp_db | gzip > myapp_db_$(date +%Y%m%d_%H%M%S).sql.gz

# Dump all databases (as root)
mysqldump -u root -p --all-databases > all_databases.sql

# Dump structure only (no data)
mysqldump -u myapp_user -p --no-data myapp_db > myapp_db_schema.sql
```

**Restore:**

```bash
# Restore from SQL file
mysql -u myapp_user -p myapp_db < myapp_db_backup.sql

# Restore from gzipped file
gunzip < myapp_db_20240101_120000.sql.gz | mysql -u myapp_user -p myapp_db
```

**Automated daily backup script:**

```bash
sudo nano /usr/local/bin/backup-mysql.sh
```

```bash
#!/bin/bash
# MySQL automated backup script with 7-day rotation

BACKUP_DIR="/home/deploy/backups/mysql"
DB_NAME="myapp_db"
DB_USER="myapp_user"
DB_PASS="SecurePassword123!"
DAYS_TO_KEEP=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create the backup
mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" | gzip > "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"

# Check if backup succeeded
if [ $? -eq 0 ]; then
    echo "[$(date)] Backup successful: ${DB_NAME}_${TIMESTAMP}.sql.gz"
else
    echo "[$(date)] ERROR: Backup failed for $DB_NAME" >&2
    exit 1
fi

# Delete backups older than DAYS_TO_KEEP
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -type f -mtime +$DAYS_TO_KEEP -delete

echo "[$(date)] Cleanup complete. Removed backups older than $DAYS_TO_KEEP days."
```

```bash
# Make it executable
sudo chmod +x /usr/local/bin/backup-mysql.sh

# Test it
sudo /usr/local/bin/backup-mysql.sh
```

### 4.2 PostgreSQL Backup & Restore

**Manual backup:**

```bash
# Dump a single database (custom format — best for restore flexibility)
pg_dump -U myapp_user -h localhost -Fc myapp_db > myapp_db_backup.dump

# Dump as plain SQL
pg_dump -U myapp_user -h localhost myapp_db > myapp_db_backup.sql

# Dump with compression
pg_dump -U myapp_user -h localhost myapp_db | gzip > myapp_db_$(date +%Y%m%d_%H%M%S).sql.gz

# Dump ALL databases (roles + databases)
sudo -u postgres pg_dumpall > all_databases.sql

# Dump structure only
pg_dump -U myapp_user -h localhost --schema-only myapp_db > myapp_db_schema.sql
```

**Restore:**

```bash
# Restore from custom format (.dump)
pg_restore -U myapp_user -h localhost -d myapp_db --clean --if-exists myapp_db_backup.dump

# Restore from plain SQL
psql -U myapp_user -h localhost -d myapp_db < myapp_db_backup.sql

# Restore from gzipped SQL
gunzip < myapp_db_20240101_120000.sql.gz | psql -U myapp_user -h localhost -d myapp_db

# Restore all databases
sudo -u postgres psql < all_databases.sql
```

**Automated daily backup script:**

```bash
sudo nano /usr/local/bin/backup-postgres.sh
```

```bash
#!/bin/bash
# PostgreSQL automated backup script with 7-day rotation

BACKUP_DIR="/home/deploy/backups/postgres"
DB_NAME="myapp_db"
DB_USER="myapp_user"
DAYS_TO_KEEP=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create the backup (custom format for flexible restore)
pg_dump -U "$DB_USER" -h localhost -Fc "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.dump"

# Check if backup succeeded
if [ $? -eq 0 ]; then
    echo "[$(date)] Backup successful: ${DB_NAME}_${TIMESTAMP}.dump"
else
    echo "[$(date)] ERROR: Backup failed for $DB_NAME" >&2
    exit 1
fi

# Delete backups older than DAYS_TO_KEEP
find "$BACKUP_DIR" -name "${DB_NAME}_*.dump" -type f -mtime +$DAYS_TO_KEEP -delete

echo "[$(date)] Cleanup complete. Removed backups older than $DAYS_TO_KEEP days."
```

```bash
sudo chmod +x /usr/local/bin/backup-postgres.sh

# For password-less pg_dump, create a .pgpass file
nano ~/.pgpass
```

```
# Format: hostname:port:database:username:password
localhost:5432:myapp_db:myapp_user:SecurePassword123!
```

```bash
chmod 600 ~/.pgpass

# Test the backup
/usr/local/bin/backup-postgres.sh
```

### 4.3 Cron Job Setup

```bash
# Edit the crontab
sudo crontab -e
```

```bash
# MySQL backup — every day at 2:00 AM
0 2 * * * /usr/local/bin/backup-mysql.sh >> /var/log/backup-mysql.log 2>&1

# PostgreSQL backup — every day at 2:30 AM
30 2 * * * /usr/local/bin/backup-postgres.sh >> /var/log/backup-postgres.log 2>&1
```

```bash
# Verify cron jobs are registered
sudo crontab -l

# Create the log files
sudo touch /var/log/backup-mysql.log /var/log/backup-postgres.log
sudo chmod 664 /var/log/backup-mysql.log /var/log/backup-postgres.log
```

### 4.4 Backup Rotation Summary

| Setting | Value | Effect |
|---|---|---|
| `DAYS_TO_KEEP=7` | 7 days | Keeps the last 7 days of backups |
| `find ... -mtime +7 -delete` | Auto-cleanup | Removes files older than 7 days |
| Cron schedule | Daily at 2:00/2:30 AM | Runs during low-traffic hours |

**Tip:** For critical databases, also copy backups off-server:

```bash
# Add to the end of your backup script
rsync -az "$BACKUP_DIR/" user@backup-server:/backups/mysql/

# Or use rclone for S3/B2/GCS
rclone copy "$BACKUP_DIR/" remote:bucket-name/mysql-backups/
```

---

## 5. Database Management Commands

### 5.1 MySQL Cheatsheet

```bash
# Connect
mysql -u myapp_user -p myapp_db
```

```sql
-- ═══════════════════════════════════════
-- DATABASE OPERATIONS
-- ═══════════════════════════════════════

SHOW DATABASES;                              -- List all databases
CREATE DATABASE newdb CHARACTER SET utf8mb4;  -- Create database
DROP DATABASE newdb;                          -- Delete database
USE myapp_db;                                -- Switch database

-- ═══════════════════════════════════════
-- TABLE OPERATIONS
-- ═══════════════════════════════════════

SHOW TABLES;                                 -- List tables
DESCRIBE users;                              -- Show table structure
SHOW CREATE TABLE users;                     -- Show full CREATE statement
SHOW TABLE STATUS;                           -- Table sizes and row counts

-- ═══════════════════════════════════════
-- USER MANAGEMENT
-- ═══════════════════════════════════════

SELECT user, host FROM mysql.user;           -- List all users
SHOW GRANTS FOR 'myapp_user'@'localhost';    -- Show user permissions
DROP USER 'olduser'@'localhost';             -- Delete a user

-- ═══════════════════════════════════════
-- COMMON QUERIES
-- ═══════════════════════════════════════

SELECT COUNT(*) FROM users;                  -- Count rows
SELECT * FROM users LIMIT 10;               -- First 10 rows
SELECT * FROM users ORDER BY created_at DESC LIMIT 5;  -- Latest 5

-- ═══════════════════════════════════════
-- SERVER STATUS
-- ═══════════════════════════════════════

SHOW PROCESSLIST;                            -- Active connections
SHOW VARIABLES LIKE 'max_connections';       -- Check a setting
SHOW STATUS LIKE 'Threads_connected';        -- Current connections
SHOW ENGINE INNODB STATUS\G                  -- InnoDB details

-- ═══════════════════════════════════════
-- SIZE QUERIES
-- ═══════════════════════════════════════

-- Database size
SELECT table_schema AS 'Database',
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
GROUP BY table_schema;

-- Table sizes in current database
SELECT table_name AS 'Table',
       ROUND((data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)',
       table_rows AS 'Rows'
FROM information_schema.tables
WHERE table_schema = DATABASE()
ORDER BY (data_length + index_length) DESC;
```

### 5.2 PostgreSQL Cheatsheet

```bash
# Connect
psql -U myapp_user -d myapp_db -h localhost
```

```sql
-- ═══════════════════════════════════════
-- PSQL META-COMMANDS (backslash commands)
-- ═══════════════════════════════════════

\l                  -- List all databases
\c myapp_db         -- Switch to database
\dt                 -- List tables in current schema
\dt+                -- List tables with sizes
\d users            -- Describe table structure
\d+ users           -- Describe table with extra detail
\du                 -- List all roles/users
\dn                 -- List schemas
\di                 -- List indexes
\df                 -- List functions
\x                  -- Toggle expanded display (like MySQL's \G)
\timing             -- Toggle query timing on/off
\q                  -- Quit

-- ═══════════════════════════════════════
-- DATABASE OPERATIONS
-- ═══════════════════════════════════════

CREATE DATABASE newdb OWNER myapp_user;
DROP DATABASE newdb;

-- ═══════════════════════════════════════
-- USER / ROLE MANAGEMENT
-- ═══════════════════════════════════════

CREATE ROLE readonly WITH LOGIN PASSWORD 'pass123';
GRANT CONNECT ON DATABASE myapp_db TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
ALTER ROLE myapp_user WITH PASSWORD 'NewPassword!';
DROP ROLE olduser;

-- ═══════════════════════════════════════
-- COMMON QUERIES
-- ═══════════════════════════════════════

SELECT COUNT(*) FROM users;
SELECT * FROM users LIMIT 10;
SELECT * FROM users ORDER BY created_at DESC LIMIT 5;

-- ═══════════════════════════════════════
-- SERVER STATUS
-- ═══════════════════════════════════════

-- Active connections
SELECT pid, usename, datname, state, query
FROM pg_stat_activity
WHERE state = 'active';

-- Connection count
SELECT count(*) FROM pg_stat_activity;

-- ═══════════════════════════════════════
-- SIZE QUERIES
-- ═══════════════════════════════════════

-- Database size
SELECT pg_database.datname,
       pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;

-- Table sizes
SELECT relname AS "Table",
       pg_size_pretty(pg_total_relation_size(relid)) AS "Total Size",
       pg_size_pretty(pg_relation_size(relid)) AS "Data Size",
       n_live_tup AS "Row Count"
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC;

-- Kill a stuck query
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE pid = 12345;
```

---

## 6. Database Migration Tips

### 6.1 Laravel Migrations

```bash
# Create a migration
php artisan make:migration create_users_table

# Run all pending migrations
php artisan migrate

# Rollback the last batch
php artisan migrate:rollback

# Rollback all and re-run
php artisan migrate:fresh

# Check migration status
php artisan migrate:status

# Run on production (force, no prompt)
php artisan migrate --force
```

Example migration file:

```php
// database/migrations/2024_01_01_000000_create_users_table.php
public function up(): void
{
    Schema::create('users', function (Blueprint $table) {
        $table->id();
        $table->string('name');
        $table->string('email')->unique();
        $table->timestamp('email_verified_at')->nullable();
        $table->string('password');
        $table->rememberToken();
        $table->timestamps();
    });
}

public function down(): void
{
    Schema::dropIfExists('users');
}
```

### 6.2 Prisma / Sequelize / TypeORM Migrations

**Prisma (Node.js)**

```bash
# Edit prisma/schema.prisma, then:
npx prisma migrate dev --name init        # Development: create & apply migration
npx prisma migrate deploy                  # Production: apply pending migrations
npx prisma migrate status                  # Check migration status
npx prisma db push                         # Sync schema without migration files (prototyping)
npx prisma generate                        # Regenerate the Prisma client
```

**Sequelize (Node.js)**

```bash
# Initialize Sequelize CLI
npx sequelize-cli init

# Create a migration
npx sequelize-cli migration:generate --name create-users

# Run migrations
npx sequelize-cli db:migrate

# Undo last migration
npx sequelize-cli db:migrate:undo

# Undo all
npx sequelize-cli db:migrate:undo:all
```

**TypeORM (Node.js/TypeScript)**

```bash
# Generate a migration from entity changes
npx typeorm migration:generate src/migrations/CreateUsers -d src/data-source.ts

# Run migrations
npx typeorm migration:run -d src/data-source.ts

# Revert last migration
npx typeorm migration:revert -d src/data-source.ts

# Show migration status
npx typeorm migration:show -d src/data-source.ts
```

### 6.3 Raw SQL Migrations

For projects without an ORM, manage migrations manually:

```bash
# Create a migrations directory
mkdir -p migrations
```

```bash
# Name files with timestamps for ordering
# migrations/001_create_users.sql
# migrations/002_add_email_index.sql
# migrations/003_create_orders.sql
```

Example `migrations/001_create_users.sql`:

```sql
-- UP
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DOWN (save separately or comment out)
-- DROP TABLE IF EXISTS users;
```

Simple migration runner script:

```bash
#!/bin/bash
# run-migrations.sh — Apply all SQL migrations in order

DB_NAME="myapp_db"
DB_USER="myapp_user"
DB_HOST="localhost"
MIGRATIONS_DIR="./migrations"

# For MySQL:
for file in "$MIGRATIONS_DIR"/*.sql; do
    echo "Applying: $file"
    mysql -u "$DB_USER" -p "$DB_NAME" < "$file"
done

# For PostgreSQL:
# for file in "$MIGRATIONS_DIR"/*.sql; do
#     echo "Applying: $file"
#     psql -U "$DB_USER" -h "$DB_HOST" -d "$DB_NAME" -f "$file"
# done
```

---

## 7. Troubleshooting

### 7.1 Can't Connect to Database

```bash
# ── MySQL ──
# Check if MySQL is running
sudo systemctl status mysql

# Check which port it's listening on
sudo ss -tlnp | grep mysql

# Check bind address
grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf

# Try connecting with verbose output
mysql -u myapp_user -p -h 127.0.0.1 --verbose

# ── PostgreSQL ──
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Check listening port
sudo ss -tlnp | grep postgres

# Check pg_hba.conf for your connection type
sudo cat /etc/postgresql/14/main/pg_hba.conf | grep -v '^#' | grep -v '^$'

# Check listen_addresses
sudo -u postgres psql -c "SHOW listen_addresses;"
```

### 7.2 Access Denied

```bash
# ── MySQL ──
# Verify user exists
sudo mysql -e "SELECT user, host FROM mysql.user;"

# Reset a user's password
sudo mysql -e "ALTER USER 'myapp_user'@'localhost' IDENTIFIED BY 'NewPassword123!';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Check grants
sudo mysql -e "SHOW GRANTS FOR 'myapp_user'@'localhost';"

# ── PostgreSQL ──
# Check role exists
sudo -u postgres psql -c "\du"

# Reset password
sudo -u postgres psql -c "ALTER ROLE myapp_user WITH PASSWORD 'NewPassword123!';"

# Check pg_hba.conf auth method (peer vs scram-sha-256 vs md5)
# If connecting via TCP (-h localhost), you need password auth, not peer
sudo cat /etc/postgresql/14/main/pg_hba.conf | grep myapp
```

### 7.3 Too Many Connections

```bash
# ── MySQL ──
# Check current vs max connections
mysql -u root -p -e "SHOW STATUS LIKE 'Threads_connected';"
mysql -u root -p -e "SHOW VARIABLES LIKE 'max_connections';"

# See who is connected
mysql -u root -p -e "SHOW PROCESSLIST;"

# Kill a specific connection
mysql -u root -p -e "KILL 12345;"

# Increase max_connections temporarily
mysql -u root -p -e "SET GLOBAL max_connections = 200;"

# ── PostgreSQL ──
# Check current vs max connections
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
sudo -u postgres psql -c "SHOW max_connections;"

# See who is connected
sudo -u postgres psql -c "SELECT pid, usename, datname, state FROM pg_stat_activity;"

# Terminate idle connections
sudo -u postgres psql -c "
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
  AND pid <> pg_backend_pid();"
```

### 7.4 Slow Queries

```bash
# ── MySQL ──
# Enable slow query log
mysql -u root -p -e "SET GLOBAL slow_query_log = 'ON';"
mysql -u root -p -e "SET GLOBAL long_query_time = 2;"

# View slow query log
sudo tail -50 /var/log/mysql/slow.log

# Find queries without indexes
mysql -u root -p -e "SHOW STATUS LIKE 'Select_full_join';"

# Analyze a slow query
mysql -u myapp_user -p myapp_db -e "EXPLAIN SELECT * FROM users WHERE email = 'test@test.com';"

# ── PostgreSQL ──
# Enable query logging (in postgresql.conf)
# log_min_duration_statement = 2000  (logs queries > 2 seconds)

# View recent slow queries from log
sudo tail -50 /var/log/postgresql/postgresql-14-main.log

# Analyze a query
psql -U myapp_user -d myapp_db -c "EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@test.com';"

# Find missing indexes (tables with lots of sequential scans)
sudo -u postgres psql -d myapp_db -c "
SELECT relname, seq_scan, idx_scan,
       CASE WHEN seq_scan + idx_scan > 0
            THEN ROUND(100.0 * idx_scan / (seq_scan + idx_scan), 1)
            ELSE 0 END AS idx_usage_pct
FROM pg_stat_user_tables
ORDER BY seq_scan DESC
LIMIT 10;"
```

### 7.5 Disk Space Issues

```bash
# Check overall disk usage
df -h

# ── MySQL ──
# Find database sizes
sudo mysql -e "
SELECT table_schema AS 'Database',
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
GROUP BY table_schema
ORDER BY SUM(data_length + index_length) DESC;"

# Check binary logs eating disk space
sudo mysql -e "SHOW BINARY LOGS;"

# Purge old binary logs (keep last 3 days)
sudo mysql -e "PURGE BINARY LOGS BEFORE DATE(NOW() - INTERVAL 3 DAY);"

# Optimize a table (reclaim space after deletes)
mysql -u myapp_user -p -e "OPTIMIZE TABLE myapp_db.large_table;"

# ── PostgreSQL ──
# Find database sizes
sudo -u postgres psql -c "
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database ORDER BY pg_database_size(datname) DESC;"

# Find large tables
sudo -u postgres psql -d myapp_db -c "
SELECT relname, pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC LIMIT 10;"

# Reclaim space (PostgreSQL doesn't auto-shrink after deletes)
sudo -u postgres vacuumdb --analyze myapp_db

# Full vacuum (locks table — run during maintenance window)
sudo -u postgres psql -d myapp_db -c "VACUUM FULL VERBOSE;"
```

---

## 8. Security Best Practices

### 8.1 Never Use Root for Applications

```sql
-- MySQL: create a limited user
CREATE USER 'app'@'localhost' IDENTIFIED BY 'StrongAppPass!';
GRANT SELECT, INSERT, UPDATE, DELETE ON myapp_db.* TO 'app'@'localhost';
FLUSH PRIVILEGES;

-- PostgreSQL: create a limited role
CREATE ROLE app WITH LOGIN PASSWORD 'StrongAppPass!';
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app;
```

Always follow the **principle of least privilege**: your app should only have the permissions it actually needs.

### 8.2 Use Strong Passwords

```bash
# Generate a strong random password
openssl rand -base64 32
# Example output: k8Tj3mZ9Qw+Fp2Lx5nR7Yv0aBcDeFgHiJkLmNoPqRs=

# Or use pwgen if installed
sudo apt install pwgen -y
pwgen -s 32 1
```

Password rules:
- Minimum 16 characters
- Mix of uppercase, lowercase, numbers, symbols
- Unique per database/service
- Store in `.env` files (never commit to git)

### 8.3 Restrict to Localhost

```bash
# ── MySQL ──
# Verify bind address is localhost
grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf
# Should show: bind-address = 127.0.0.1

# ── PostgreSQL ──
# Verify listen_addresses
sudo -u postgres psql -c "SHOW listen_addresses;"
# Should show: localhost

# Firewall: block database ports from outside
sudo ufw deny 3306  # MySQL
sudo ufw deny 5432  # PostgreSQL
```

### 8.4 Regular Backups

- ✅ Automate backups with cron (see [Section 4](#4-backup--restore))
- ✅ Test restores regularly — a backup you can't restore is worthless
- ✅ Store backups off-server (S3, B2, another VPS)
- ✅ Encrypt backups if they contain sensitive data:

```bash
# Encrypt a backup with GPG
gpg --symmetric --cipher-algo AES256 myapp_db_backup.sql.gz
# Creates: myapp_db_backup.sql.gz.gpg

# Decrypt
gpg --decrypt myapp_db_backup.sql.gz.gpg > myapp_db_backup.sql.gz
```

### 8.5 Additional Security Measures

```bash
# Keep database software updated
sudo apt update && sudo apt upgrade -y

# Disable remote root login (MySQL)
sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
sudo mysql -e "FLUSH PRIVILEGES;"

# Remove default/test databases
sudo mysql -e "DROP DATABASE IF EXISTS test;"

# Monitor login attempts (PostgreSQL)
# In postgresql.conf:
# log_connections = on
# log_disconnections = on
```

### Security Checklist

| Check | MySQL | PostgreSQL |
|---|---|---|
| App uses non-root user | ☐ | ☐ |
| Strong passwords (16+ chars) | ☐ | ☐ |
| Bound to localhost only | ☐ | ☐ |
| Firewall blocks DB ports | ☐ | ☐ |
| Daily automated backups | ☐ | ☐ |
| Backups tested & off-server | ☐ | ☐ |
| Slow query log enabled | ☐ | ☐ |
| Software up to date | ☐ | ☐ |
| No test databases present | ☐ | ☐ |
| `.env` files in `.gitignore` | ☐ | ☐ |

---

> **Next steps:** [Deployment Guide](../DEPLOYMENT-GUIDE.md) · [Nginx Configs](../nginx/) · [SSL Setup](../ssl/)
