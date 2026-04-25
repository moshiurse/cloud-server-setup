# Monitoring & Alerting Guide

Complete guide to monitoring your VPS, applications, and services. All commands are for **Ubuntu 22.04 LTS**.

---

## Table of Contents

1. [Server Health Monitoring](#1-server-health-monitoring)
2. [PM2 Monitoring](#2-pm2-monitoring)
3. [Nginx Monitoring](#3-nginx-monitoring)
4. [Uptime Monitoring (External)](#4-uptime-monitoring-external)
5. [Application-Level Monitoring](#5-application-level-monitoring)
6. [Alerting](#6-alerting)
7. [Quick Monitoring Setup Script](#7-quick-monitoring-setup-script)

---

## 1. Server Health Monitoring

### CPU Monitoring

**Using `top` (built-in):**
```bash
# Interactive view — press 'q' to quit
top

# Batch mode — snapshot of current state
top -bn1 | head -20
```

Key fields in `top`:
- **%us** — user CPU (your apps)
- **%sy** — system/kernel CPU
- **%id** — idle (higher is better)
- **load average** — 1/5/15 min averages (should be below your CPU core count)

**Using `htop` (recommended):**
```bash
sudo apt install -y htop
htop
```

`htop` gives color-coded per-core CPU bars, tree view of processes, and easy sorting. Press `F6` to sort by CPU or memory.

**Quick CPU check (no interactive UI):**
```bash
# Current load average
uptime

# CPU core count (load average should stay below this)
nproc

# Per-core usage snapshot
mpstat -P ALL 1 1
```

---

### Memory Monitoring

```bash
free -h
```

Example output:
```
              total        used        free      shared  buff/cache   available
Mem:          3.8Gi       1.2Gi       512Mi       128Mi       2.1Gi       2.2Gi
Swap:         2.0Gi       256Mi       1.7Gi
```

**Understanding the output:**
| Field | What It Means |
|-------|---------------|
| `total` | Physical RAM installed |
| `used` | RAM actively used by processes |
| `free` | Completely unused RAM |
| `buff/cache` | RAM used for disk cache (can be reclaimed) |
| **`available`** | **RAM available for new processes (the number that matters)** |

> **Rule of thumb:** Watch `available`, not `free`. Linux uses spare RAM for disk cache, which is normal. Worry when `available` drops below 10–15% of `total`.

**Check top memory consumers:**
```bash
ps aux --sort=-%mem | head -10
```

---

### Disk Usage Monitoring

**Overall disk usage:**
```bash
df -h
```

Focus on the row where `Mounted on` is `/` — that's your root partition.

**Directory sizes:**
```bash
# Size of a specific directory
du -sh /var/log
du -sh /home/*

# Top 10 largest directories under root
du -h --max-depth=1 / 2>/dev/null | sort -rh | head -10
```

**Find large files:**
```bash
# Files over 100MB
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null

# Files over 500MB
find / -type f -size +500M -exec ls -lh {} \; 2>/dev/null

# Top 20 largest files on the system
find / -type f -exec du -h {} + 2>/dev/null | sort -rh | head -20
```

**Common space wasters to check:**
```bash
# Old log files
du -sh /var/log/*

# Old journal logs (safe to trim)
sudo journalctl --disk-usage
sudo journalctl --vacuum-size=100M

# Old apt cache
sudo apt clean

# Old snap versions
snap list --all | awk '/disabled/{print $1, $3}' | while read name rev; do sudo snap remove "$name" --revision="$rev"; done
```

---

### Network Monitoring

**Using `iftop` (bandwidth per connection):**
```bash
sudo apt install -y iftop
sudo iftop -i eth0
```

**Using `nethogs` (bandwidth per process):**
```bash
sudo apt install -y nethogs
sudo nethogs eth0
```

**Quick bandwidth check:**
```bash
# Current connections count
ss -s

# Active connections to your web server
ss -tn | grep ':80\|:443' | wc -l

# Bytes transferred on interface
cat /proc/net/dev | grep eth0
```

**Check open ports:**
```bash
sudo ss -tlnp
```

---

### Process Monitoring

```bash
# All processes sorted by CPU
ps aux --sort=-%cpu | head -15

# All processes sorted by memory
ps aux --sort=-%mem | head -15

# Find a specific process
ps aux | grep nginx
ps aux | grep node

# Count running processes
ps aux | wc -l
```

**Watch a process in real-time:**
```bash
# Update every 2 seconds
watch -n 2 'ps aux --sort=-%cpu | head -10'
```

---

### Quick Health Check Script

Save as `/usr/local/bin/server-health` and run anytime with `server-health`:

```bash
#!/bin/bash
# server-health — Quick server health overview
# Usage: server-health

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Server Health Check — $(hostname)${NC}"
echo -e "${CYAN}  $(date)${NC}"
echo -e "${CYAN}========================================${NC}"

# Uptime & Load
echo -e "\n${GREEN}▶ UPTIME & LOAD${NC}"
uptime

CORES=$(nproc)
LOAD=$(awk '{print $1}' /proc/loadavg)
echo "CPU Cores: $CORES | Load: $LOAD"
if (( $(echo "$LOAD > $CORES" | bc -l) )); then
    echo -e "${RED}⚠ Load is higher than CPU core count!${NC}"
fi

# CPU
echo -e "\n${GREEN}▶ CPU USAGE${NC}"
top -bn1 | grep "Cpu(s)" | awk '{print "User: "$2"% | System: "$4"% | Idle: "$8"%"}'

# Memory
echo -e "\n${GREEN}▶ MEMORY${NC}"
free -h | awk '/^Mem:/ {printf "Total: %s | Used: %s | Available: %s\n", $2, $3, $7}'
free -h | awk '/^Swap:/ {printf "Swap Total: %s | Swap Used: %s\n", $2, $3}'

MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
if [ "$MEM_PERCENT" -gt 90 ]; then
    echo -e "${RED}⚠ Memory usage is above 90%!${NC}"
elif [ "$MEM_PERCENT" -gt 75 ]; then
    echo -e "${YELLOW}⚠ Memory usage is above 75%${NC}"
fi

# Disk
echo -e "\n${GREEN}▶ DISK USAGE${NC}"
df -h / | awk 'NR==2 {printf "Root: %s used of %s (%s)\n", $3, $2, $5}'

DISK_PERCENT=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_PERCENT" -gt 90 ]; then
    echo -e "${RED}⚠ Disk usage is above 90%!${NC}"
elif [ "$DISK_PERCENT" -gt 75 ]; then
    echo -e "${YELLOW}⚠ Disk usage is above 75%${NC}"
fi

# Services
echo -e "\n${GREEN}▶ KEY SERVICES${NC}"
for svc in nginx pm2-$(whoami) mysql postgresql; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "  ${GREEN}● $svc — running${NC}"
    elif systemctl list-units --type=service --all 2>/dev/null | grep -q "$svc"; then
        echo -e "  ${RED}● $svc — stopped${NC}"
    fi
done

# PM2 (if available)
if command -v pm2 &>/dev/null; then
    echo -e "\n${GREEN}▶ PM2 PROCESSES${NC}"
    pm2 list
fi

# Top Processes
echo -e "\n${GREEN}▶ TOP 5 PROCESSES (by CPU)${NC}"
ps aux --sort=-%cpu | awk 'NR<=6 {printf "%-10s %5s%% CPU  %5s%% MEM  %s\n", $1, $3, $4, $11}'

echo -e "\n${GREEN}▶ TOP 5 PROCESSES (by Memory)${NC}"
ps aux --sort=-%mem | awk 'NR<=6 {printf "%-10s %5s%% CPU  %5s%% MEM  %s\n", $1, $3, $4, $11}'

echo -e "\n${CYAN}========================================${NC}"
```

**Install it:**
```bash
sudo tee /usr/local/bin/server-health > /dev/null << 'SCRIPT'
# Paste the script above here
SCRIPT

sudo chmod +x /usr/local/bin/server-health
```

Now run `server-health` from anywhere.

---

## 2. PM2 Monitoring

### Basic PM2 Monitoring Commands

```bash
# List all processes with status
pm2 status

# Real-time dashboard (CPU, memory, logs)
pm2 monit

# Detailed info for a specific app
pm2 show my-app

# Real-time logs
pm2 logs
pm2 logs my-app --lines 50
```

### PM2 Metrics

```bash
# Check restart count (high count = app is crashing)
pm2 show my-app | grep -E "restart|uptime|memory|cpu"

# Reset restart count after fixing issues
pm2 reset my-app

# Describe all running metrics
pm2 describe my-app
```

**Key metrics to watch:**
| Metric | Healthy | Investigate |
|--------|---------|-------------|
| Status | `online` | `errored`, `stopped` |
| Restarts | Low / stable | Increasing rapidly |
| Memory | Below `max_memory_restart` | Growing continuously (memory leak) |
| CPU | Below 80% sustained | Pegged at 100% |
| Uptime | Hours/days | Seconds/minutes (crash loop) |

### PM2 Plus (Paid Dashboard)

PM2 Plus provides a web dashboard with historical metrics, error tracking, and deployment tracking.

```bash
# Link your server (creates a free account if needed)
pm2 plus
```

Free tier includes 1 server. Useful if you want a quick hosted dashboard without self-hosting anything. See [pm2.io](https://pm2.io) for pricing.

### Custom PM2 Monitoring with pm2-server-monit

`pm2-server-monit` adds server-level metrics (CPU, memory, disk) to PM2's monitoring.

```bash
pm2 install pm2-server-monit
```

After installation, PM2 Plus will show server metrics alongside your app metrics.

### Setting Up PM2 Alerts

**Memory threshold restart (in ecosystem config):**

```javascript
// ecosystem.config.js
module.exports = {
  apps: [
    {
      name: 'my-app',
      script: 'npm',
      args: 'start',

      // Restart if memory exceeds 512MB (prevents OOM kills)
      max_memory_restart: '512M',

      // Restart on crash, with increasing delay
      exp_backoff_restart_delay: 100,

      // Max restarts within a time window
      max_restarts: 10,
      min_uptime: '10s',

      // Log settings
      error_file: '/home/deploy/logs/my-app-error.log',
      out_file: '/home/deploy/logs/my-app-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    },
  ],
};
```

**PM2 crash alert script:**

Save as `/usr/local/bin/pm2-alert-check`:

```bash
#!/bin/bash
# Check PM2 for crashed or stopped apps and send alerts

ALERT_EMAIL="admin@yourdomain.com"

# Get all apps that are NOT online
ISSUES=$(pm2 jlist 2>/dev/null | python3 -c "
import sys, json
apps = json.load(sys.stdin)
for app in apps:
    status = app.get('pm2_env', {}).get('status', 'unknown')
    restarts = app.get('pm2_env', {}).get('restart_time', 0)
    name = app.get('name', 'unknown')
    if status != 'online' or restarts > 50:
        print(f'{name}: status={status}, restarts={restarts}')
" 2>/dev/null)

if [ -n "$ISSUES" ]; then
    echo -e "PM2 Alert on $(hostname)\n\n$ISSUES" | \
        mail -s "⚠ PM2 Alert: $(hostname)" "$ALERT_EMAIL"
fi
```

```bash
sudo chmod +x /usr/local/bin/pm2-alert-check

# Run every 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/pm2-alert-check") | crontab -
```

---

## 3. Nginx Monitoring

### Access and Error Logs

```bash
# Default log locations
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Per-site logs (if configured)
tail -f /var/log/nginx/yourdomain-access.log
tail -f /var/log/nginx/yourdomain-error.log

# Last 100 error log entries
tail -100 /var/log/nginx/error.log

# Only critical errors
grep -E "emerg|alert|crit" /var/log/nginx/error.log
```

### Nginx Status Module (stub_status)

**Enable the status endpoint:**

```nginx
# /etc/nginx/sites-available/default (or your site config)
# Add this inside the server block:

location /nginx_status {
    stub_status on;
    allow 127.0.0.1;      # Only allow localhost
    allow YOUR_IP;         # Your IP for remote checks
    deny all;              # Block everyone else
}
```

```bash
# Test and reload
sudo nginx -t && sudo systemctl reload nginx

# Check status
curl http://127.0.0.1/nginx_status
```

**Output explained:**
```
Active connections: 45
server accepts handled requests
 12345 12345 67890
Reading: 2 Writing: 5 Waiting: 38
```

| Field | Meaning |
|-------|---------|
| Active connections | Current client connections (including waiting) |
| accepts | Total accepted connections |
| handled | Total handled connections (should equal accepts) |
| requests | Total client requests |
| Reading | Nginx reading request headers |
| Writing | Nginx sending response to client |
| Waiting | Keep-alive connections waiting for next request |

**Monitor Nginx status in a loop:**
```bash
watch -n 1 'curl -s http://127.0.0.1/nginx_status'
```

### Real-Time Log Analysis Commands

```bash
# Watch requests in real-time (simplified)
tail -f /var/log/nginx/access.log | awk '{print $1, $7, $9}'

# Watch only errors (4xx and 5xx)
tail -f /var/log/nginx/access.log | awk '$9 >= 400'

# Watch only 5xx errors
tail -f /var/log/nginx/access.log | awk '$9 >= 500'

# Requests per second (last 1000 lines)
tail -1000 /var/log/nginx/access.log | awk '{print $4}' | cut -d: -f1-3 | sort | uniq -c | sort -rn | head
```

### Nginx Log Format Customization

Add a more detailed log format to `/etc/nginx/nginx.conf` inside the `http {}` block:

```nginx
log_format detailed '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    '$request_time $upstream_response_time';
```

Then use it in your site config:
```nginx
access_log /var/log/nginx/yourdomain-access.log detailed;
```

The `$request_time` field is especially useful — it shows how long each request took (in seconds), which helps identify slow endpoints.

### Useful grep/awk Commands for Log Analysis

**Top 20 visitor IPs:**
```bash
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20
```

**Top 20 requested URLs:**
```bash
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20
```

**HTTP status code breakdown:**
```bash
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn
```

**All 404 errors (what are people looking for?):**
```bash
awk '$9 == 404 {print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20
```

**All 5xx errors with timestamps:**
```bash
awk '$9 >= 500 {print $4, $7, $9}' /var/log/nginx/access.log | tail -20
```

**Requests per hour (traffic pattern):**
```bash
awk '{print $4}' /var/log/nginx/access.log | cut -d: -f1-2 | sort | uniq -c
```

**Top user agents (find bots):**
```bash
awk -F'"' '{print $6}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -20
```

**Bandwidth usage by IP (top 10):**
```bash
awk '{a[$1]+=$10} END {for (i in a) printf "%15s %10.2f MB\n", i, a[i]/1048576}' \
    /var/log/nginx/access.log | sort -k2 -rn | head -10
```

**Requests from a specific IP:**
```bash
grep "203.0.113.50" /var/log/nginx/access.log | tail -20
```

---

## 4. Uptime Monitoring (External)

External monitoring checks your site from outside your server. If your server goes down, you still get alerted.

### UptimeRobot (Free Tier — 50 Monitors)

[UptimeRobot](https://uptimerobot.com) is the go-to free uptime monitoring service.

**Setup an HTTP monitor:**
1. Create a free account at [uptimerobot.com](https://uptimerobot.com)
2. Click **"Add New Monitor"**
3. Configure:
   - **Monitor Type:** HTTP(s)
   - **Friendly Name:** My App (Production)
   - **URL:** `https://yourdomain.com`
   - **Monitoring Interval:** 5 minutes (free tier)
4. Click **"Create Monitor"**

**Setup a keyword monitor** (checks page content, not just HTTP 200):
1. **Monitor Type:** Keyword
2. **URL:** `https://yourdomain.com/api/health`
3. **Keyword:** `"ok"` (or whatever your health endpoint returns)
4. **Keyword Type:** Keyword exists

This ensures your app is actually responding correctly, not just returning a generic error page with HTTP 200.

**Alert channels:**

Go to **My Settings → Alert Contacts** and add:

- **Email** — added by default
- **Slack** — use an incoming webhook URL
- **Telegram:**
  1. Message [@uptimerobot_bot](https://t.me/uptimerobot_bot) on Telegram
  2. It gives you an integration code
  3. Paste it in UptimeRobot alert contacts

**Recommended monitors for each app:**
| Monitor | URL | Type |
|---------|-----|------|
| Website | `https://yourdomain.com` | HTTP(s) |
| Health check | `https://yourdomain.com/api/health` | Keyword ("ok") |
| API | `https://api.yourdomain.com/v1/status` | HTTP(s) |
| SSL expiry | `https://yourdomain.com` | HTTP(s) + SSL alert |

### Better Stack (betterstack.com)

[Better Stack](https://betterstack.com) (formerly Better Uptime) offers uptime monitoring + incident management + status pages. Free tier includes 10 monitors with 3-minute intervals. Better than UptimeRobot if you want a public status page.

### Freshping

[Freshping](https://www.freshworks.com/website-monitoring/) by Freshworks offers 50 free monitors with 1-minute check intervals. Good alternative to UptimeRobot with a cleaner UI.

### Self-Hosted: Uptime Kuma

[Uptime Kuma](https://github.com/louislam/uptime-kuma) is a self-hosted monitoring tool with a beautiful UI. Perfect if you want full control.

**Quick setup with Docker:**

```bash
# Install Docker (if not already installed)
curl -fsSL https://get.docker.com | sh

# Run Uptime Kuma
docker run -d \
  --name uptime-kuma \
  --restart=unless-stopped \
  -p 3001:3001 \
  -v uptime-kuma:/app/data \
  louislam/uptime-kuma:1
```

Access at `http://YOUR_SERVER_IP:3001`.

**Nginx reverse proxy for Uptime Kuma:**

```nginx
# /etc/nginx/sites-available/status.yourdomain.com
server {
    listen 80;
    server_name status.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/status.yourdomain.com /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Then get SSL
sudo certbot --nginx -d status.yourdomain.com
```

> **Note:** Run Uptime Kuma on a **different server** than the one it monitors, otherwise it can't alert you when the server goes down.

---

## 5. Application-Level Monitoring

### Health Check Endpoints

Health endpoints let monitoring tools verify your app is working, not just that the server responds.

**Node.js / Express:**

```javascript
// routes/health.js
const express = require('express');
const router = express.Router();

router.get('/api/health', async (req, res) => {
  const healthcheck = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
  };

  try {
    // Add your own checks here (database, redis, etc.)
    // await db.query('SELECT 1');
    res.status(200).json(healthcheck);
  } catch (error) {
    healthcheck.status = 'error';
    healthcheck.error = error.message;
    res.status(503).json(healthcheck);
  }
});

module.exports = router;
```

**Next.js API Route:**

```javascript
// pages/api/health.js (Pages Router)
// or app/api/health/route.js (App Router)

// --- Pages Router ---
export default function handler(req, res) {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
}

// --- App Router ---
export async function GET() {
  return Response.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
}
```

**PHP:**

```php
<?php
// health.php
header('Content-Type: application/json');

$health = [
    'status' => 'ok',
    'timestamp' => date('c'),
    'php_version' => phpversion(),
];

// Optional: Check database connection
try {
    $pdo = new PDO('mysql:host=127.0.0.1;dbname=mydb', 'user', 'password');
    $health['database'] = 'connected';
} catch (PDOException $e) {
    $health['status'] = 'error';
    $health['database'] = 'disconnected';
    http_response_code(503);
}

echo json_encode($health);
```

### Response Time Monitoring

**Quick check from the server itself:**
```bash
# Response time for your health endpoint
curl -o /dev/null -s -w "HTTP %{http_code} | Time: %{time_total}s | DNS: %{time_namelookup}s | Connect: %{time_connect}s | TTFB: %{time_starttransfer}s\n" \
    https://yourdomain.com/api/health
```

**Continuous monitoring script:**

```bash
#!/bin/bash
# response-monitor.sh — Log response times every minute
URL="https://yourdomain.com/api/health"
LOGFILE="/home/deploy/logs/response-times.log"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    RESULT=$(curl -o /dev/null -s -w "%{http_code} %{time_total}" "$URL")
    HTTP_CODE=$(echo "$RESULT" | awk '{print $1}')
    TIME=$(echo "$RESULT" | awk '{print $2}')
    echo "$TIMESTAMP | HTTP $HTTP_CODE | ${TIME}s" >> "$LOGFILE"
    sleep 60
done
```

### Error Tracking with Sentry

[Sentry](https://sentry.io) captures errors with full stack traces, context, and user info. Free tier includes 5K errors/month.

**Node.js setup:**

```bash
npm install @sentry/node
```

```javascript
// At the very top of your entry file (server.js / app.js)
const Sentry = require('@sentry/node');

Sentry.init({
  dsn: 'https://your-dsn@sentry.io/project-id',
  environment: process.env.NODE_ENV || 'production',
  tracesSampleRate: 0.1, // 10% of transactions for performance monitoring
});

// Express error handler (add AFTER all routes)
app.use(Sentry.Handlers.errorHandler());
```

**PHP setup:**

```bash
composer require sentry/sentry
```

```php
<?php
// At the top of your entry file
\Sentry\init([
    'dsn' => 'https://your-dsn@sentry.io/project-id',
    'environment' => 'production',
    'traces_sample_rate' => 0.1,
]);
```

Get your DSN from: **Sentry Dashboard → Settings → Projects → Your Project → Client Keys (DSN)**

---

## 6. Alerting

### Email Alerts for Disk Space

First, install a mail utility:

```bash
sudo apt install -y mailutils

# Configure with a relay service like SendGrid or use system mail
# For simple setups, use msmtp:
sudo apt install -y msmtp msmtp-mta

# Configure /etc/msmtprc
sudo tee /etc/msmtprc > /dev/null << 'EOF'
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        default
host           smtp.gmail.com
port           587
from           your-alerts@gmail.com
user           your-alerts@gmail.com
password       your-app-password
EOF

sudo chmod 600 /etc/msmtprc
```

> **Tip:** Use a Gmail "App Password" (not your regular password). Go to Google Account → Security → App Passwords.

**Simple disk space alert:**
```bash
#!/bin/bash
# disk-alert.sh
THRESHOLD=80
ALERT_EMAIL="admin@yourdomain.com"

USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

if [ "$USAGE" -gt "$THRESHOLD" ]; then
    echo "Disk usage on $(hostname) is at ${USAGE}% (threshold: ${THRESHOLD}%)" | \
        mail -s "⚠ Disk Alert: $(hostname) at ${USAGE}%" "$ALERT_EMAIL"
fi
```

### Cron-Based Alert Script

Save as `/usr/local/bin/server-alert-check`:

```bash
#!/bin/bash
# server-alert-check — Check critical thresholds and send email alerts
# Run via cron every 10 minutes

ALERT_EMAIL="admin@yourdomain.com"
HOSTNAME=$(hostname)
ALERTS=""

# --- Disk Usage Check ---
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 85 ]; then
    ALERTS="$ALERTS\n⚠ DISK: Root partition at ${DISK_USAGE}%"
fi

# --- Memory Check ---
MEM_AVAILABLE_MB=$(free -m | awk '/^Mem:/ {print $7}')
MEM_TOTAL_MB=$(free -m | awk '/^Mem:/ {print $2}')
MEM_USED_PERCENT=$(( (MEM_TOTAL_MB - MEM_AVAILABLE_MB) * 100 / MEM_TOTAL_MB ))
if [ "$MEM_USED_PERCENT" -gt 90 ]; then
    ALERTS="$ALERTS\n⚠ MEMORY: ${MEM_USED_PERCENT}% used (${MEM_AVAILABLE_MB}MB available)"
fi

# --- Swap Check ---
SWAP_USED=$(free -m | awk '/^Swap:/ {print $3}')
if [ "$SWAP_USED" -gt 500 ]; then
    ALERTS="$ALERTS\n⚠ SWAP: ${SWAP_USED}MB used (possible memory pressure)"
fi

# --- Nginx Check ---
if ! systemctl is-active --quiet nginx; then
    ALERTS="$ALERTS\n🔴 NGINX: Service is DOWN"
fi

# --- PM2 Check ---
if command -v pm2 &>/dev/null; then
    PM2_ISSUES=$(pm2 jlist 2>/dev/null | python3 -c "
import sys, json
try:
    apps = json.load(sys.stdin)
    for app in apps:
        env = app.get('pm2_env', {})
        status = env.get('status', 'unknown')
        name = app.get('name', 'unknown')
        if status != 'online':
            print(f'  - {name}: {status}')
except:
    pass
" 2>/dev/null)
    if [ -n "$PM2_ISSUES" ]; then
        ALERTS="$ALERTS\n🔴 PM2 APPS DOWN:\n$PM2_ISSUES"
    fi
fi

# --- SSL Certificate Expiry Check ---
for DOMAIN in yourdomain.com api.yourdomain.com; do
    EXPIRY_DATE=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN":443 2>/dev/null | \
        openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -n "$EXPIRY_DATE" ]; then
        EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null)
        NOW_EPOCH=$(date +%s)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
        if [ "$DAYS_LEFT" -lt 14 ]; then
            ALERTS="$ALERTS\n⚠ SSL: $DOMAIN expires in ${DAYS_LEFT} days"
        fi
    fi
done

# --- Send Alert (only if there are issues) ---
if [ -n "$ALERTS" ]; then
    SUBJECT="⚠ Server Alert: $HOSTNAME"
    BODY="Server alerts for $HOSTNAME at $(date):\n$ALERTS\n\n--- Server Health ---\n$(free -h)\n\n$(df -h /)"
    echo -e "$BODY" | mail -s "$SUBJECT" "$ALERT_EMAIL"
fi
```

**Install and schedule:**
```bash
sudo cp server-alert-check /usr/local/bin/
sudo chmod +x /usr/local/bin/server-alert-check

# Run every 10 minutes
(crontab -l 2>/dev/null; echo "*/10 * * * * /usr/local/bin/server-alert-check") | crontab -
```

### Telegram Bot Alerts

Telegram is the easiest alert channel — no email config needed.

**Step 1: Create a Telegram bot:**
1. Message [@BotFather](https://t.me/botfather) on Telegram
2. Send `/newbot`
3. Give it a name (e.g., "My Server Alerts")
4. Copy the **bot token** (e.g., `123456:ABC-DEF...`)

**Step 2: Get your chat ID:**
1. Message your new bot (send it anything)
2. Visit: `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates`
3. Find `"chat":{"id":123456789}` — that's your chat ID

**Step 3: Send alerts from bash:**

```bash
#!/bin/bash
# telegram-alert.sh — Send a message via Telegram
# Usage: telegram-alert.sh "Your alert message here"

BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
CHAT_ID="123456789"
MESSAGE="$1"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="🖥 $(hostname): $MESSAGE" \
    -d parse_mode="Markdown" > /dev/null
```

```bash
sudo cp telegram-alert.sh /usr/local/bin/telegram-alert
sudo chmod +x /usr/local/bin/telegram-alert

# Test it
telegram-alert "Test alert from server"
```

**Use it in your alert scripts:**
```bash
# Replace the mail command in any script above with:
telegram-alert "⚠ Disk usage on $(hostname) at ${DISK_USAGE}%"
```

### Slack Webhook Alerts

**Step 1: Create an incoming webhook:**
1. Go to [api.slack.com/messaging/webhooks](https://api.slack.com/messaging/webhooks)
2. Create a new app → Incoming Webhooks → Activate
3. Add webhook to a channel
4. Copy the webhook URL

**Step 2: Send alerts from bash:**

```bash
#!/bin/bash
# slack-alert.sh — Send a message to Slack
# Usage: slack-alert.sh "Your alert message here"

WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
MESSAGE="$1"

curl -s -X POST "$WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d "{
        \"text\": \"🖥 *$(hostname)*: $MESSAGE\",
        \"username\": \"Server Alert\",
        \"icon_emoji\": \":warning:\"
    }" > /dev/null
```

```bash
sudo cp slack-alert.sh /usr/local/bin/slack-alert
sudo chmod +x /usr/local/bin/slack-alert

# Test it
slack-alert "Test alert from server"
```

---

## 7. Quick Monitoring Setup Script

One script to set up basic monitoring on a fresh server. Save as `setup-monitoring.sh`:

```bash
#!/bin/bash
# setup-monitoring.sh — Set up basic monitoring on Ubuntu 22.04
# Usage: sudo bash setup-monitoring.sh

set -e

# --- Colors ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Monitoring Setup for Ubuntu 22.04${NC}"
echo -e "${CYAN}========================================${NC}"

# --- Configuration (edit these) ---
ALERT_EMAIL="admin@yourdomain.com"           # Where to send alerts
DEPLOY_USER="deploy"                          # Your deploy username
DOMAIN="yourdomain.com"                       # Your primary domain
DISK_THRESHOLD=85                             # Disk alert threshold (%)
MEM_THRESHOLD=90                              # Memory alert threshold (%)

# =============================================
# 1. Install monitoring tools
# =============================================
echo -e "\n${GREEN}[1/5] Installing monitoring tools...${NC}"
apt update -qq
apt install -y htop iftop nethogs curl bc mailutils

echo "✅ htop, iftop, nethogs installed"

# =============================================
# 2. Create server-health command
# =============================================
echo -e "\n${GREEN}[2/5] Creating server-health command...${NC}"

cat > /usr/local/bin/server-health << 'HEALTHSCRIPT'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Server Health — $(hostname)${NC}"
echo -e "${CYAN}  $(date)${NC}"
echo -e "${CYAN}========================================${NC}"

echo -e "\n${GREEN}▶ UPTIME & LOAD${NC}"
uptime
echo "CPU Cores: $(nproc)"

echo -e "\n${GREEN}▶ CPU${NC}"
top -bn1 | grep "Cpu(s)" | awk '{print "User: "$2"% | System: "$4"% | Idle: "$8"%"}'

echo -e "\n${GREEN}▶ MEMORY${NC}"
free -h | awk '/^Mem:/ {printf "Total: %s | Used: %s | Available: %s\n", $2, $3, $7}'
free -h | awk '/^Swap:/ {printf "Swap: %s used of %s\n", $3, $2}'

echo -e "\n${GREEN}▶ DISK${NC}"
df -h / | awk 'NR==2 {printf "Root: %s used of %s (%s)\n", $3, $2, $5}'

echo -e "\n${GREEN}▶ SERVICES${NC}"
for svc in nginx pm2-deploy mysql postgresql; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "  ${GREEN}● $svc — running${NC}"
    elif systemctl list-units --type=service --all 2>/dev/null | grep -q "$svc"; then
        echo -e "  ${RED}● $svc — stopped${NC}"
    fi
done

if command -v pm2 &>/dev/null; then
    echo -e "\n${GREEN}▶ PM2${NC}"
    pm2 list 2>/dev/null
fi

echo -e "\n${GREEN}▶ TOP PROCESSES (CPU)${NC}"
ps aux --sort=-%cpu | awk 'NR>1 && NR<=6 {printf "%-10s %5s%% CPU  %5s%% MEM  %s\n", $1, $3, $4, $11}'

echo -e "\n${GREEN}▶ TOP PROCESSES (Memory)${NC}"
ps aux --sort=-%mem | awk 'NR>1 && NR<=6 {printf "%-10s %5s%% CPU  %5s%% MEM  %s\n", $1, $3, $4, $11}'

echo ""
HEALTHSCRIPT

chmod +x /usr/local/bin/server-health
echo "✅ server-health command created"

# =============================================
# 3. Enable Nginx stub_status
# =============================================
echo -e "\n${GREEN}[3/5] Enabling Nginx stub_status...${NC}"

if command -v nginx &>/dev/null; then
    # Check if stub_status is already configured
    if ! grep -r "stub_status" /etc/nginx/ &>/dev/null; then
        # Create a status config snippet
        cat > /etc/nginx/conf.d/stub-status.conf << 'NGINXSTATUS'
server {
    listen 127.0.0.1:8080;
    server_name localhost;

    location /nginx_status {
        stub_status on;
        allow 127.0.0.1;
        deny all;
    }
}
NGINXSTATUS
        nginx -t && systemctl reload nginx
        echo "✅ Nginx stub_status enabled at http://127.0.0.1:8080/nginx_status"
    else
        echo "✅ Nginx stub_status already configured"
    fi
else
    echo "⏭ Nginx not installed — skipping"
fi

# =============================================
# 4. Create health check cron
# =============================================
echo -e "\n${GREEN}[4/5] Creating health check cron job...${NC}"

cat > /usr/local/bin/health-check-cron << CRONSCRIPT
#!/bin/bash
# Runs every 5 minutes — logs server health summary

LOGFILE="/var/log/server-health.log"
TIMESTAMP=\$(date '+%Y-%m-%d %H:%M:%S')
LOAD=\$(awk '{print \$1}' /proc/loadavg)
MEM=\$(free | awk '/^Mem:/ {printf "%.0f", \$3/\$2 * 100}')
DISK=\$(df / | awk 'NR==2 {print \$5}' | tr -d '%')
NGINX=\$(systemctl is-active nginx 2>/dev/null || echo "n/a")

echo "\$TIMESTAMP | Load: \$LOAD | Mem: \${MEM}% | Disk: \${DISK}% | Nginx: \$NGINX" >> "\$LOGFILE"

# Keep log file manageable (last 10000 lines)
tail -10000 "\$LOGFILE" > "\$LOGFILE.tmp" && mv "\$LOGFILE.tmp" "\$LOGFILE"
CRONSCRIPT

chmod +x /usr/local/bin/health-check-cron

# Add to cron if not already there
if ! crontab -l 2>/dev/null | grep -q "health-check-cron"; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/health-check-cron") | crontab -
fi

echo "✅ Health check cron job created (every 5 minutes)"
echo "   Logs to: /var/log/server-health.log"

# =============================================
# 5. Create disk space alert cron
# =============================================
echo -e "\n${GREEN}[5/5] Creating disk space alert cron...${NC}"

cat > /usr/local/bin/disk-alert-cron << ALERTSCRIPT
#!/bin/bash
# Disk and memory alert check — runs every 10 minutes

ALERT_EMAIL="${ALERT_EMAIL}"
HOSTNAME=\$(hostname)
DISK_THRESHOLD=${DISK_THRESHOLD}
MEM_THRESHOLD=${MEM_THRESHOLD}
ALERTS=""

# Disk check
DISK_USAGE=\$(df / | awk 'NR==2 {print \$5}' | tr -d '%')
if [ "\$DISK_USAGE" -gt "\$DISK_THRESHOLD" ]; then
    ALERTS="\$ALERTS\n⚠ DISK: Root partition at \${DISK_USAGE}% (threshold: \${DISK_THRESHOLD}%)"
fi

# Memory check
MEM_TOTAL=\$(free -m | awk '/^Mem:/ {print \$2}')
MEM_AVAILABLE=\$(free -m | awk '/^Mem:/ {print \$7}')
MEM_USED_PCT=\$(( (MEM_TOTAL - MEM_AVAILABLE) * 100 / MEM_TOTAL ))
if [ "\$MEM_USED_PCT" -gt "\$MEM_THRESHOLD" ]; then
    ALERTS="\$ALERTS\n⚠ MEMORY: \${MEM_USED_PCT}% used (\${MEM_AVAILABLE}MB available)"
fi

# Nginx check
if command -v nginx &>/dev/null && ! systemctl is-active --quiet nginx; then
    ALERTS="\$ALERTS\n🔴 NGINX is DOWN"
fi

# Send alert
if [ -n "\$ALERTS" ]; then
    BODY="Alerts for \$HOSTNAME at \$(date):\n\$ALERTS\n\nDisk:\n\$(df -h /)\n\nMemory:\n\$(free -h)"
    echo -e "\$BODY" | mail -s "⚠ Server Alert: \$HOSTNAME" "\$ALERT_EMAIL" 2>/dev/null

    # Also log it
    echo "\$(date '+%Y-%m-%d %H:%M:%S') | ALERT SENT: \$ALERTS" >> /var/log/server-alerts.log
fi
ALERTSCRIPT

chmod +x /usr/local/bin/disk-alert-cron

# Add to cron if not already there
if ! crontab -l 2>/dev/null | grep -q "disk-alert-cron"; then
    (crontab -l 2>/dev/null; echo "*/10 * * * * /usr/local/bin/disk-alert-cron") | crontab -
fi

echo "✅ Disk/memory alert cron created (every 10 minutes)"
echo "   Alerts sent to: ${ALERT_EMAIL}"

# =============================================
# Done
# =============================================
echo -e "\n${CYAN}========================================${NC}"
echo -e "${GREEN}  ✅ Monitoring setup complete!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo "Commands available:"
echo "  server-health          — Quick server health overview"
echo "  htop                   — Interactive process monitor"
echo "  sudo iftop -i eth0     — Network bandwidth monitor"
echo "  sudo nethogs eth0      — Per-process bandwidth"
echo ""
echo "Cron jobs installed:"
echo "  */5  * * * * health-check-cron   → /var/log/server-health.log"
echo "  */10 * * * * disk-alert-cron     → email alerts"
echo ""
echo "Next steps:"
echo "  1. Edit ALERT_EMAIL in /usr/local/bin/disk-alert-cron"
echo "  2. Configure mail (msmtp or mailutils) for email alerts"
echo "  3. Set up UptimeRobot at https://uptimerobot.com"
echo "  4. Add health check endpoints to your apps"
echo ""
```

**Run it:**
```bash
# Edit the configuration section first, then:
sudo bash setup-monitoring.sh
```

---

## Quick Reference

| What | Command |
|------|---------|
| Server health overview | `server-health` |
| Interactive process monitor | `htop` |
| PM2 process list | `pm2 status` |
| PM2 real-time monitor | `pm2 monit` |
| PM2 logs | `pm2 logs` |
| Nginx status | `curl http://127.0.0.1:8080/nginx_status` |
| Nginx error log | `tail -f /var/log/nginx/error.log` |
| Disk usage | `df -h` |
| Memory usage | `free -h` |
| Network bandwidth | `sudo iftop -i eth0` |
| Per-process bandwidth | `sudo nethogs eth0` |
| Health check log | `tail -f /var/log/server-health.log` |
| Alert log | `tail -f /var/log/server-alerts.log` |
| Test Telegram alert | `telegram-alert "Test message"` |
| Test Slack alert | `slack-alert "Test message"` |
