# Log Rotation Guide — Ubuntu 22.04 VPS

Keep your VPS healthy by preventing logs from eating all your disk space.

---

## 1. Why Log Rotation Matters

Logs grow silently until your disk is full. When that happens, databases crash, deploys fail, and your site goes down.

**Real-world scenario:** A Node.js app running under PM2 with `console.log` statements can generate 10GB+ of logs in weeks — especially if you're logging request bodies or errors in a loop.

**Quick check — how much space are logs using right now?**

```bash
# Top-level log disk usage
sudo du -sh /var/log

# Largest log files on the system
sudo find /var/log -type f -name "*.log" -exec du -sh {} + | sort -rh | head -20

# PM2 logs specifically
du -sh ~/.pm2/logs/

# Nginx logs
sudo du -sh /var/log/nginx/

# Overall disk usage
df -h /
```

If `/var/log` is over 1GB or your disk is above 80% full, you need to act now.

---

## 2. PM2 Log Rotation

### The Problem

PM2 writes stdout and stderr to `~/.pm2/logs/` with no size limit and no rotation by default. A busy app can produce gigabytes of logs.

```bash
# See current PM2 log sizes
ls -lhS ~/.pm2/logs/
```

### Install pm2-logrotate

```bash
pm2 install pm2-logrotate
```

### Configure pm2-logrotate

```bash
# Max size per log file before rotation (default: 10M)
pm2 set pm2-logrotate:max_size 50M

# Keep this many rotated files (default: 30)
pm2 set pm2-logrotate:retain 7

# Enable gzip compression for rotated logs
pm2 set pm2-logrotate:compress true

# Rotation check interval in seconds (default: 30)
pm2 set pm2-logrotate:workerInterval 30

# Cron-style rotation schedule (runs daily at 1 AM)
pm2 set pm2-logrotate:rotateInterval '0 1 * * *'

# Date format for rotated filenames
pm2 set pm2-logrotate:dateFormat YYYY-MM-DD_HH-mm-ss

# Rotate PM2's own module logs too
pm2 set pm2-logrotate:rotateModule true
```

### All pm2-logrotate Settings Explained

| Setting          | Default              | Description                                         |
|------------------|----------------------|-----------------------------------------------------|
| `max_size`       | `10M`                | Rotate when a log file exceeds this size            |
| `retain`         | `30`                 | Number of rotated files to keep per app             |
| `compress`       | `false`              | Gzip rotated log files                              |
| `dateFormat`     | `YYYY-MM-DD_HH-mm-ss` | Timestamp format appended to rotated filenames    |
| `workerInterval` | `30`                 | Seconds between size checks                         |
| `rotateInterval` | `0 0 * * *`          | Cron expression for time-based rotation             |
| `rotateModule`   | `true`               | Also rotate logs from PM2 modules                   |
| `TZ`             | system TZ            | Timezone for cron schedule                          |

### Manual PM2 Log Flush

```bash
# Flush all PM2 logs immediately (truncates to 0 bytes)
pm2 flush

# Flush logs for a specific app
pm2 flush my-app

# Rotate logs right now (keeps current content in rotated file)
pm2 reloadLogs
```

### Recommended Settings for a VPS

```bash
pm2 set pm2-logrotate:max_size 50M
pm2 set pm2-logrotate:retain 7
pm2 set pm2-logrotate:compress true
pm2 set pm2-logrotate:rotateInterval '0 1 * * *'
pm2 set pm2-logrotate:rotateModule true
```

This keeps roughly 350MB max per app (7 × 50MB) and compresses old files.

---

## 3. Nginx Log Rotation

### Default logrotate Config

Ubuntu ships with Nginx log rotation pre-configured:

```bash
cat /etc/logrotate.d/nginx
```

Default contents:

```
/var/log/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    prerotate
        if [ -d /etc/logrotate.d/httpd-prerotate ]; then
            run-parts /etc/logrotate.d/httpd-prerotate
        fi
    endscript
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1
    endscript
}
```

### Customize Rotation

Edit `/etc/logrotate.d/nginx`:

```bash
sudo nano /etc/logrotate.d/nginx
```

**Daily rotation, keep 7 days:**

```
/var/log/nginx/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1
    endscript
}
```

**Size-based rotation (rotate when logs hit 100MB):**

```
/var/log/nginx/*.log {
    size 100M
    rotate 5
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1
    endscript
}
```

### Compressed vs Uncompressed

| Directive        | Effect                                                  |
|------------------|---------------------------------------------------------|
| `compress`       | Gzip rotated logs (saves ~90% space)                    |
| `delaycompress`  | Don't compress the most recent rotated file             |
| `nocompress`     | Keep all rotated files uncompressed                     |
| `compresscmd`    | Use a different compressor (e.g., `zstd`, `xz`)        |

`delaycompress` is useful because some tools may still be writing to the just-rotated file.

### Per-Site Log Rotation

If you have per-site logs like `/var/log/nginx/mysite.access.log`, create a dedicated config:

```bash
sudo tee /etc/logrotate.d/nginx-mysite << 'EOF'
/var/log/nginx/mysite.access.log
/var/log/nginx/mysite.error.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1
    endscript
}
EOF
```

---

## 4. System Log Rotation (logrotate)

### How logrotate Works

1. A cron job runs `logrotate` daily (via `/etc/cron.daily/logrotate`).
2. It reads the main config at `/etc/logrotate.conf`.
3. It processes every file in `/etc/logrotate.d/`.
4. For each matching log file, it checks age/size and rotates if needed.

```bash
# See the main config
cat /etc/logrotate.conf

# List all rotation configs
ls /etc/logrotate.d/
```

### Configuration Syntax

```
/path/to/your/logfile.log {
    daily|weekly|monthly|yearly   # rotation frequency
    rotate 7                      # keep N rotated files
    size 100M                     # rotate when file exceeds size (overrides frequency)
    compress                      # gzip old logs
    delaycompress                 # skip compressing the newest rotated file
    missingok                     # don't error if log file is missing
    notifempty                    # skip rotation if log is empty
    create 0640 user group        # permissions for the new empty log file
    copytruncate                  # truncate in place (for apps that hold the file open)
    sharedscripts                 # run pre/post scripts once, not per file
    postrotate                    # command to run after rotation
        systemctl reload myapp
    endscript
}
```

### Create Custom logrotate Configs

Example for a Laravel app:

```bash
sudo tee /etc/logrotate.d/my-laravel-app << 'EOF'
/var/www/myapp/storage/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0664 www-data www-data
}
EOF
```

Example for a custom Node.js app writing to `/var/log/myapp/`:

```bash
sudo tee /etc/logrotate.d/myapp << 'EOF'
/var/log/myapp/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    create 0644 deploy deploy
}
EOF
```

> Use `copytruncate` when the app keeps the log file open (can't reopen on signal). Note: you may lose a few lines written between copy and truncate.

### Test logrotate Configs (Dry Run)

```bash
# Dry run — shows what would happen, changes nothing
sudo logrotate -d /etc/logrotate.d/myapp

# Verbose dry run for the entire config
sudo logrotate -dv /etc/logrotate.conf
```

### Force Rotation

```bash
# Force immediate rotation of a specific config
sudo logrotate -f /etc/logrotate.d/myapp

# Force rotation of everything
sudo logrotate -f /etc/logrotate.conf
```

---

## 5. Application Log Rotation

### PHP / Laravel Logs

**Use the `daily` log channel** so Laravel creates one file per day:

```php
// config/logging.php
'channels' => [
    'stack' => [
        'driver' => 'stack',
        'channels' => ['daily'],
    ],
    'daily' => [
        'driver' => 'daily',
        'path' => storage_path('logs/laravel.log'),
        'days' => 14,  // keep 14 days of logs
    ],
],
```

**Manual cleanup of old Laravel logs:**

```bash
# Delete Laravel logs older than 14 days
find /var/www/myapp/storage/logs -name "laravel-*.log" -mtime +14 -delete
```

### Node.js — Winston Log Rotation

```bash
npm install winston-daily-rotate-file
```

```js
const winston = require('winston');
require('winston-daily-rotate-file');

const transport = new winston.transports.DailyRotateFile({
  filename: '/var/log/myapp/app-%DATE%.log',
  datePattern: 'YYYY-MM-DD',
  maxSize: '50m',      // rotate at 50MB
  maxFiles: '14d',     // keep 14 days
  compress: true,      // gzip old files
});

const logger = winston.createLogger({
  transports: [transport],
});
```

### Node.js — Pino Log Rotation

Pino writes to stdout by default. Pipe through `pino-rotating-file`:

```bash
npm install pino-rotating-file
```

```bash
# In your PM2 ecosystem or startup script
node app.js | pino-rotating-file --path /var/log/myapp/ --size 50M --keep 7
```

Or let PM2 handle the files and rely on `pm2-logrotate` (simpler approach).

### MySQL Slow Query Logs

```bash
# Check if slow query log is enabled and where it writes
mysql -e "SHOW VARIABLES LIKE 'slow_query_log%';"
```

Add a logrotate config:

```bash
sudo tee /etc/logrotate.d/mysql-slow << 'EOF'
/var/log/mysql/mysql-slow.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 0640 mysql adm
    postrotate
        # Tell MySQL to reopen the log file
        mysqladmin flush-logs slow
    endscript
}
EOF
```

---

## 6. Automated Cleanup Script

### Cleanup Script

```bash
sudo tee /usr/local/bin/cleanup-logs.sh << 'SCRIPT'
#!/bin/bash
# cleanup-logs.sh — Remove old logs, temp files, and alert on low disk space

set -euo pipefail

LOG_TAG="cleanup-logs"
DISK_THRESHOLD=85  # alert when disk usage exceeds this percentage

log() {
    logger -t "$LOG_TAG" "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting log cleanup"

# 1. Clean old rotated/compressed logs (older than 30 days)
find /var/log -name "*.gz" -mtime +30 -delete 2>/dev/null && \
    log "Removed compressed logs older than 30 days"

find /var/log -name "*.old" -mtime +30 -delete 2>/dev/null && \
    log "Removed .old logs older than 30 days"

# 2. Clean journal logs older than 7 days
if command -v journalctl &>/dev/null; then
    journalctl --vacuum-time=7d --quiet
    log "Vacuumed journald logs to 7 days"
fi

# 3. Clean old PM2 logs (rotated files older than 14 days)
PM2_LOG_DIR="$HOME/.pm2/logs"
if [ -d "$PM2_LOG_DIR" ]; then
    find "$PM2_LOG_DIR" -name "*.gz" -mtime +14 -delete 2>/dev/null
    find "$PM2_LOG_DIR" -name "*__*" -mtime +14 -delete 2>/dev/null
    log "Cleaned PM2 rotated logs older than 14 days"
fi

# 4. Clean APT cache
if command -v apt-get &>/dev/null; then
    apt-get clean -qq
    log "Cleaned APT cache"
fi

# 5. Remove old temp files
find /var/tmp -type f -mtime +7 -delete 2>/dev/null || true

# 6. Disk space alert
DISK_USAGE=$(df / | awk 'NR==2 {gsub("%",""); print $5}')
if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    ALERT_MSG="DISK ALERT: / is ${DISK_USAGE}% full on $(hostname)"
    log "$ALERT_MSG"

    # Send email if mail is configured
    if command -v mail &>/dev/null; then
        echo "$ALERT_MSG" | mail -s "$ALERT_MSG" root
    fi
fi

log "Cleanup complete. Disk usage: ${DISK_USAGE}%"
SCRIPT

sudo chmod +x /usr/local/bin/cleanup-logs.sh
```

### Cron Job Setup

```bash
# Run cleanup daily at 2 AM
(sudo crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/cleanup-logs.sh >> /var/log/cleanup-logs.log 2>&1") | sudo crontab -

# Verify cron entry
sudo crontab -l
```

### Disk Space Alert (Standalone)

A lightweight cron-only alert if you don't want the full script:

```bash
# Add to root's crontab — checks every 6 hours
(sudo crontab -l 2>/dev/null; echo '0 */6 * * * [ $(df / | awk "NR==2 {gsub(\"%\",\"\"); print \$5}") -gt 85 ] && echo "Disk space critical on $(hostname): $(df -h /)" | logger -t disk-alert') | sudo crontab -
```

---

## 7. Quick Setup

Copy-paste this block to set up sensible log rotation on a typical VPS running PM2 + Nginx:

```bash
#!/bin/bash
# quick-log-rotation-setup.sh
# Run as your deploy user (PM2 commands) then as root (system commands)

set -euo pipefail
echo "=== Log Rotation Quick Setup ==="

# --- PM2 logrotate ---
echo "[1/4] Configuring PM2 log rotation..."
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 50M
pm2 set pm2-logrotate:retain 7
pm2 set pm2-logrotate:compress true
pm2 set pm2-logrotate:rotateInterval '0 1 * * *'
pm2 set pm2-logrotate:rotateModule true
echo "      PM2 logrotate configured."

# --- Verify Nginx logrotate ---
echo "[2/4] Verifying Nginx log rotation..."
if [ -f /etc/logrotate.d/nginx ]; then
    echo "      Nginx logrotate config exists."
    sudo logrotate -d /etc/logrotate.d/nginx 2>&1 | head -5
else
    echo "      WARNING: /etc/logrotate.d/nginx not found. Creating one..."
    sudo tee /etc/logrotate.d/nginx > /dev/null << 'NGINX'
/var/log/nginx/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1
    endscript
}
NGINX
fi

# --- Disk monitoring cron ---
echo "[3/4] Setting up disk monitoring cron..."
CRON_CMD='0 */6 * * * [ $(df / | awk "NR==2 {gsub(\"%\",\"\"); print \$5}") -gt 85 ] && echo "DISK ALERT on $(hostname): $(df -h /)" | logger -t disk-alert'
(sudo crontab -l 2>/dev/null | grep -v "disk-alert"; echo "$CRON_CMD") | sudo crontab -
echo "      Disk alert cron installed (checks every 6 hours, warns at 85%)."

# --- Current status ---
echo "[4/4] Current disk and log status:"
echo "      Disk: $(df -h / | awk 'NR==2 {print $5, "used of", $2}')"
echo "      /var/log: $(sudo du -sh /var/log 2>/dev/null | cut -f1)"
echo "      PM2 logs: $(du -sh ~/.pm2/logs/ 2>/dev/null | cut -f1 || echo 'N/A')"

echo ""
echo "=== Done. Logs are under control. ==="
```

Save and run:

```bash
chmod +x quick-log-rotation-setup.sh
./quick-log-rotation-setup.sh
```

---

## Cheat Sheet

| Task                          | Command                                      |
|-------------------------------|----------------------------------------------|
| Check disk usage              | `df -h /`                                    |
| Find large log files          | `sudo find /var/log -size +100M`             |
| Flush PM2 logs now            | `pm2 flush`                                  |
| Force logrotate               | `sudo logrotate -f /etc/logrotate.conf`      |
| Test logrotate config         | `sudo logrotate -d /etc/logrotate.d/myapp`   |
| Vacuum journald               | `sudo journalctl --vacuum-time=7d`           |
| PM2 logrotate settings        | `pm2 conf pm2-logrotate`                     |
| Nginx log sizes               | `sudo du -sh /var/log/nginx/`                |
