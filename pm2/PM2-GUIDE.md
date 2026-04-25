# PM2 — Complete Process Manager Guide

Comprehensive guide to running, managing, and monitoring Node.js applications in production using PM2.

> **Ecosystem Config Templates:**
> - [Node.js (Express/Fastify/Koa)](ecosystem-nodejs.config.js)
> - [Next.js](ecosystem-nextjs.config.js)
> - [NestJS](ecosystem-nestjs.config.js)
>
> **Related Guides:**
> - [Monitoring Guide](../docs/MONITORING-GUIDE.md)
> - [Log Rotation Guide](../docs/LOG-ROTATION-GUIDE.md)

---

## Table of Contents

1.  [What is PM2](#what-is-pm2)
2.  [Installation](#installation)
3.  [Quick Start](#quick-start)
4.  [Ecosystem File — Configuration Deep Dive](#ecosystem-file--configuration-deep-dive)
5.  [Fork Mode vs Cluster Mode](#fork-mode-vs-cluster-mode)
6.  [Environment Variables](#environment-variables)
7.  [Process Management Commands](#process-management-commands)
8.  [Startup & Auto-Restart on Reboot](#startup--auto-restart-on-reboot)
9.  [Zero-Downtime Deployments](#zero-downtime-deployments)
10. [Log Management](#log-management)
11. [Monitoring & Diagnostics](#monitoring--diagnostics)
12. [Memory & Restart Strategies](#memory--restart-strategies)
13. [Graceful Shutdown](#graceful-shutdown)
14. [Watch Mode (Development)](#watch-mode-development)
15. [Running Multiple Apps on One VPS](#running-multiple-apps-on-one-vps)
16. [PM2 with Next.js — Complete Guide](#pm2-with-nextjs--complete-guide)
17. [PM2 with NestJS — Complete Guide](#pm2-with-nestjs--complete-guide)
18. [PM2 with Express / Node.js API](#pm2-with-express--nodejs-api)
19. [PM2 Deploy (Built-in Deployment System)](#pm2-deploy-built-in-deployment-system)
20. [Cron & Scheduled Tasks with PM2](#cron--scheduled-tasks-with-pm2)
21. [PM2 Modules & Plugins](#pm2-modules--plugins)
22. [Performance Tuning](#performance-tuning)
23. [Troubleshooting](#troubleshooting)
24. [Complete Configuration Reference](#complete-configuration-reference)
25. [Quick Reference Cheatsheet](#quick-reference-cheatsheet)

---

## What is PM2

PM2 is a production process manager for Node.js applications. It provides:

- **Process management** — keep your app running forever, auto-restart on crash
- **Cluster mode** — run multiple instances across all CPU cores
- **Zero-downtime reload** — deploy new code without dropping connections
- **Log management** — centralized logging with rotation
- **Monitoring** — built-in CPU/memory monitoring
- **Startup scripts** — auto-start apps when server reboots

---

## Installation

```bash
# Install PM2 globally
sudo npm install -g pm2

# Verify installation
pm2 --version

# Update PM2
sudo npm install -g pm2@latest
pm2 update    # Update the PM2 daemon
```

### Install on Fresh VPS

```bash
# Make sure Node.js is installed first
node --version

# Install PM2
sudo npm install -g pm2

# Setup auto-completion (optional)
pm2 completion install
```

---

## Quick Start

### Start an App (Quick)

```bash
# Simplest way — start a script
pm2 start app.js

# Start with a name
pm2 start app.js --name myapp

# Start with specific port
PORT=3000 pm2 start app.js --name myapp

# Start a Next.js app
pm2 start npm --name myapp -- start

# Start with an ecosystem file (recommended)
pm2 start ecosystem.config.js
```

### First-Time Setup Flow

```bash
cd /var/www/apps/myapp

# 1. Create logs directory
mkdir -p logs

# 2. Copy the ecosystem template (pick one from pm2/ folder)
cp /path/to/vps-deployment-kit/pm2/ecosystem-nodejs.config.js ecosystem.config.js

# 3. Edit configuration
nano ecosystem.config.js

# 4. Start the app
pm2 start ecosystem.config.js

# 5. Save process list (so PM2 remembers after restart)
pm2 save

# 6. Setup auto-start on reboot
pm2 startup
# ↑ This prints a command — copy and run it!
```

---

## Ecosystem File — Configuration Deep Dive

The ecosystem file is the **recommended** way to configure PM2 apps. It gives you full control over every setting.

### Basic Structure

```javascript
// ecosystem.config.js
module.exports = {
  apps: [
    {
      name: 'myapp',          // App name in PM2
      script: 'app.js',       // Entry point
      cwd: '/var/www/apps/myapp',  // Working directory
    },
  ],
};
```

### All Configuration Options Explained

```javascript
module.exports = {
  apps: [
    {
      // ─── IDENTITY ─────────────────────────────────────
      name: 'myapp',                    // Name shown in pm2 list
      script: 'app.js',                 // Entry file to execute
      args: '',                          // Arguments passed to script
      cwd: '/var/www/apps/myapp',        // Working directory
      interpreter: 'node',              // Interpreter (node, python, ruby, bash)
      interpreter_args: '',             // Args for interpreter (e.g., --harmony)
      node_args: '--max-old-space-size=2048',  // Node.js flags

      // ─── EXECUTION MODE ───────────────────────────────
      instances: 1,                     // Number of instances
                                         //   1          = single instance
                                         //   'max'      = one per CPU core
                                         //   -1         = max minus 1
                                         //   2, 4, etc. = exact count
      exec_mode: 'fork',                // 'fork' or 'cluster'

      // ─── ENVIRONMENT ──────────────────────────────────
      env: {                            // Default environment variables
        NODE_ENV: 'production',
        PORT: 3000,
      },
      env_staging: {                    // --env staging
        NODE_ENV: 'staging',
        PORT: 3001,
      },
      env_development: {                // --env development
        NODE_ENV: 'development',
        PORT: 3000,
      },

      // ─── RESTART BEHAVIOR ─────────────────────────────
      autorestart: true,                // Auto restart on crash (default: true)
      watch: false,                     // Watch files for changes (default: false)
      max_restarts: 10,                 // Max rapid restarts before stopping
      min_uptime: '10s',                // Min uptime to consider "started"
                                         //   If app crashes before this, it's an error
      restart_delay: 4000,              // Delay between restarts (ms)
      exp_backoff_restart_delay: 100,   // Exponential backoff (100, 200, 400, 800...)
                                         //   Caps at 15000ms. Better than fixed delay.
      max_memory_restart: '500M',       // Restart if memory exceeds this
      cron_restart: '0 3 * * *',        // Restart on cron schedule (daily at 3 AM)

      // ─── LOGS ─────────────────────────────────────────
      error_file: './logs/err.log',     // Stderr log file
      out_file: './logs/out.log',       // Stdout log file
      log_file: './logs/combined.log',  // Combined log (optional)
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      time: true,                       // Prefix logs with timestamp
      merge_logs: true,                 // Merge logs from all cluster instances
                                         //   (one file instead of per-instance files)
      // Disable logs entirely:
      // out_file: '/dev/null',
      // error_file: '/dev/null',

      // ─── GRACEFUL SHUTDOWN ─────────────────────────────
      kill_timeout: 5000,               // Time (ms) to wait for graceful stop
                                         //   After this, SIGKILL is sent
      listen_timeout: 10000,            // Time (ms) to wait for app to listen
                                         //   Used by reload to know when new instance is ready
      shutdown_with_message: false,     // Send shutdown:message instead of SIGINT
      wait_ready: false,                // Wait for process.send('ready') instead of listen event
                                         //   Useful for apps with async startup (DB connections, etc.)

      // ─── SOURCE MAP & DEBUGGING ────────────────────────
      source_map_support: true,         // Enable source map support for stack traces

      // ─── ADVANCED ─────────────────────────────────────
      force: false,                     // Force start even if already running
      append_env_to_name: false,        // Append env name to process name
      filter_env: [],                   // Filter out specific env variables
      automation: true,                 // Enable PM2 automation features
      treekill: true,                   // Kill the whole tree of child processes
      vizion: true,                     // Enable versioning metadata (git info)
    },
  ],
};
```

---

## Fork Mode vs Cluster Mode

Understanding when to use each mode is critical.

### Fork Mode

```javascript
{
  instances: 1,
  exec_mode: 'fork',
}
```

| Feature | Detail |
|---------|--------|
| **How it works** | Runs a single process |
| **CPU cores used** | 1 |
| **Use when** | Next.js, apps with their own clustering, WebSocket-heavy apps |
| **Zero-downtime reload** | ❌ No (brief downtime on restart) |
| **Shared state** | N/A (single process) |

### Cluster Mode

```javascript
{
  instances: 'max',      // or a number: 2, 4
  exec_mode: 'cluster',
}
```

| Feature | Detail |
|---------|--------|
| **How it works** | Runs multiple instances using Node.js `cluster` module |
| **CPU cores used** | All (or specified count) |
| **Use when** | Express, Fastify, Koa, NestJS, any stateless HTTP server |
| **Zero-downtime reload** | ✅ Yes (`pm2 reload`) |
| **Shared state** | ❌ No (each instance is separate — use Redis for shared state) |

### Which Mode for Each Framework?

| Framework | Mode | Instances | Why |
|-----------|------|-----------|-----|
| **Express** | cluster | max | Stateless, benefits from all cores |
| **Fastify** | cluster | max | Same as Express |
| **Koa** | cluster | max | Same as Express |
| **NestJS** | cluster | max | Supports cluster mode natively |
| **Next.js** | fork | 1 | Has its own internal worker management |
| **Nuxt.js** | fork | 1 | Same as Next.js |
| **Socket.io** | fork | 1 | WebSocket connections are stateful* |
| **GraphQL subscriptions** | fork | 1 | WebSocket-based, stateful* |

> \* Socket.io and WebSocket apps _can_ run in cluster mode with a Redis adapter, but it requires additional setup. Start with fork mode.

### Cluster Mode Gotchas

```javascript
// ❌ In-memory state is NOT shared between instances
// This won't work in cluster mode:
let onlineUsers = [];  // Each instance has its own copy!

// ✅ Use Redis or a database for shared state:
const redis = require('redis');
const client = redis.createClient();
```

---

## Environment Variables

### Using Ecosystem File (Recommended)

```javascript
module.exports = {
  apps: [{
    name: 'myapp',
    script: 'app.js',

    // Default production environment
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'mysql://user:pass@localhost:3306/mydb',
    },

    // Staging (use: pm2 start ecosystem.config.js --env staging)
    env_staging: {
      NODE_ENV: 'staging',
      PORT: 3001,
      DATABASE_URL: 'mysql://user:pass@localhost:3306/staging_db',
    },
  }],
};
```

### Start with a Specific Environment

```bash
# Start with default env
pm2 start ecosystem.config.js

# Start with staging env
pm2 start ecosystem.config.js --env staging

# Start with development env
pm2 start ecosystem.config.js --env development
```

### Using .env File

If your app uses `dotenv` or reads `.env` automatically:

```bash
# Create .env file
nano /var/www/apps/myapp/.env

# Your app loads it via:
# require('dotenv').config()  (Node.js)
# or Next.js loads it automatically
```

### Update Environment Variables

```bash
# After changing env vars in ecosystem.config.js:
pm2 restart myapp --update-env

# Or reload (zero-downtime, cluster mode only):
pm2 reload myapp --update-env
```

### View Current Environment

```bash
# Show all env vars for an app
pm2 env 0          # by ID
pm2 env myapp      # by name
```

---

## Process Management Commands

### Starting

```bash
pm2 start ecosystem.config.js          # Start from ecosystem file
pm2 start app.js                        # Start a script directly
pm2 start app.js --name myapp           # Start with a name
pm2 start app.js -i max                 # Start in cluster mode (all cores)
pm2 start app.js -i 4                   # Start 4 instances
pm2 start npm --name myapp -- start     # Start an npm script
pm2 start npm --name myapp -- run dev   # Start npm run dev
pm2 start "node app.js"                 # Start a command string
```

### Stopping

```bash
pm2 stop myapp          # Stop by name
pm2 stop 0              # Stop by ID
pm2 stop all            # Stop all apps
```

### Restarting

```bash
pm2 restart myapp       # Restart (brief downtime)
pm2 restart all         # Restart all apps

# With updated environment:
pm2 restart myapp --update-env
```

### Reloading (Zero-Downtime — Cluster Mode Only)

```bash
pm2 reload myapp        # Zero-downtime reload
pm2 reload all          # Reload all apps
pm2 reload myapp --update-env  # Reload with new env vars
```

### Deleting

```bash
pm2 delete myapp        # Remove from PM2 process list
pm2 delete 0            # Remove by ID
pm2 delete all          # Remove all apps
```

### Listing

```bash
pm2 list                # List all processes
pm2 ls                  # Alias for list
pm2 status              # Alias for list
pm2 jlist               # JSON format
pm2 prettylist          # Pretty JSON
```

### Showing Details

```bash
pm2 show myapp          # Detailed info about an app
pm2 describe myapp      # Alias for show
pm2 info myapp          # Alias for show
```

### Scaling (Cluster Mode)

```bash
pm2 scale myapp 4       # Scale to exactly 4 instances
pm2 scale myapp +2      # Add 2 more instances
pm2 scale myapp -1      # Remove 1 instance
```

---

## Startup & Auto-Restart on Reboot

This is **critical** — without it, your apps won't start after a server reboot.

### Setup Auto-Start

```bash
# Step 1: Save current process list
pm2 save

# Step 2: Generate startup script
pm2 startup
# This prints a command like:
# sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u deploy --hp /home/deploy

# Step 3: Copy and run that exact command
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u deploy --hp /home/deploy

# Step 4: Verify
pm2 save
```

### How It Works

1. `pm2 save` — saves your current process list to `~/.pm2/dump.pm2`
2. `pm2 startup` — creates a systemd service that runs `pm2 resurrect` on boot
3. On reboot, PM2 automatically restarts all saved processes

### Update After Changes

```bash
# After adding/removing apps, always save:
pm2 save
```

### Remove Startup

```bash
pm2 unstartup systemd
```

### Verify It Works

```bash
# Simulate a reboot test
pm2 kill          # Kill the PM2 daemon
pm2 resurrect     # Should restore all saved apps
pm2 list          # Verify all apps are back
```

---

## Zero-Downtime Deployments

### With Cluster Mode (Best)

```bash
# Cluster mode supports true zero-downtime reload:
pm2 reload myapp

# How it works:
# 1. PM2 starts new instances with new code
# 2. Waits for them to be ready (listen_timeout)
# 3. Gracefully shuts down old instances (kill_timeout)
# 4. No requests are dropped
```

### With Fork Mode (Workaround)

Fork mode doesn't support `reload`. Options:

**Option A: Accept brief downtime**
```bash
pm2 restart myapp    # ~1-3 seconds of downtime
```

**Option B: Use `wait_ready` for faster recovery**
```javascript
// ecosystem.config.js
{
  wait_ready: true,
  listen_timeout: 10000,
}

// In your app:
app.listen(port, () => {
  process.send('ready');  // Tell PM2 the app is ready
});
```

**Option C: Multiple fork instances behind Nginx**
```javascript
// Run 2 instances on different ports
module.exports = {
  apps: [
    { name: 'myapp-1', script: 'app.js', env: { PORT: 3000 } },
    { name: 'myapp-2', script: 'app.js', env: { PORT: 3001 } },
  ],
};
```

```nginx
# Nginx upstream with both
upstream myapp {
    server 127.0.0.1:3000;
    server 127.0.0.1:3001;
}
```

Then restart one at a time:
```bash
pm2 restart myapp-1 && sleep 5 && pm2 restart myapp-2
```

### Deployment Script with Zero-Downtime

```bash
#!/bin/bash
# deploy.sh — zero-downtime deployment

set -e

APP_DIR="/var/www/apps/myapp"
APP_NAME="myapp"

echo "🚀 Starting deployment..."

cd $APP_DIR

# Pull latest code
git pull origin main

# Install dependencies
npm ci --production

# Build (if needed)
npm run build 2>/dev/null || true

# Zero-downtime reload (cluster) or restart (fork)
if pm2 describe $APP_NAME | grep -q "cluster"; then
  pm2 reload $APP_NAME --update-env
  echo "✅ Reloaded (zero-downtime)"
else
  pm2 restart $APP_NAME --update-env
  echo "✅ Restarted"
fi

pm2 save
echo "🎉 Deployment complete!"
```

---

## Log Management

### View Logs

```bash
pm2 logs                    # All app logs (real-time)
pm2 logs myapp              # Specific app logs
pm2 logs myapp --lines 200  # Last 200 lines
pm2 logs --raw              # Raw output (no formatting)
pm2 logs --json             # JSON format
pm2 logs --nostream         # Show log content, don't follow

# Filter logs
pm2 logs myapp --err        # Only error logs
pm2 logs myapp --out        # Only stdout logs
```

### Log File Locations

```bash
# Default location
~/.pm2/logs/

# Custom (from ecosystem.config.js)
./logs/err.log
./logs/out.log

# Find actual log paths
pm2 show myapp | grep "log path"
```

### Clear Logs

```bash
pm2 flush                   # Clear ALL PM2 log files
pm2 flush myapp             # Clear specific app logs
```

### Log Rotation (Critical!)

Without rotation, PM2 logs will fill your disk.

```bash
# Install log rotation module
pm2 install pm2-logrotate

# Configure (recommended settings)
pm2 set pm2-logrotate:max_size 50M        # Rotate at 50MB
pm2 set pm2-logrotate:retain 7            # Keep 7 rotated files
pm2 set pm2-logrotate:compress true       # Compress old logs
pm2 set pm2-logrotate:dateFormat YYYY-MM-DD_HH-mm
pm2 set pm2-logrotate:workerInterval 60   # Check every 60 seconds
pm2 set pm2-logrotate:rotateInterval '0 0 * * *'  # Force rotate daily at midnight

# Verify settings
pm2 conf pm2-logrotate
```

> 📖 See [Log Rotation Guide](../docs/LOG-ROTATION-GUIDE.md) for full details.

### Disable Logs (for high-throughput apps)

```javascript
{
  out_file: '/dev/null',
  error_file: '/dev/null',
}
```

---

## Monitoring & Diagnostics

### Built-in Monitoring

```bash
pm2 monit                   # Interactive dashboard (CPU, memory, logs)
pm2 list                    # Quick status overview
pm2 show myapp              # Detailed info for one app
```

### Key Metrics to Watch

```bash
pm2 show myapp
# Look for:
#   status        → online / stopped / errored
#   restarts      → high number = problem
#   uptime        → should be high, low = crashing
#   memory        → watch for leaks (growing over time)
#   cpu           → should be reasonable
```

### Detect Memory Leaks

```bash
# Watch memory over time
watch -n 5 'pm2 jlist | python3 -c "import sys,json; [print(f\"{p[\"name\"]}: {p[\"monit\"][\"memory\"]//1024//1024}MB\") for p in json.load(sys.stdin)]"'

# Or simpler:
pm2 monit    # Watch the memory column
```

### PM2 Plus (Optional — Paid)

PM2 Plus provides a web dashboard with historical metrics, alerts, and remote management.

```bash
# Link to PM2 Plus
pm2 plus
# Follow the prompts to create/link an account
```

> 📖 See [Monitoring Guide](../docs/MONITORING-GUIDE.md) for more.

---

## Memory & Restart Strategies

### Memory Limit

```javascript
{
  max_memory_restart: '500M',   // Restart if memory exceeds 500MB
}
```

Recommended memory limits by app type:

| App Type | Recommended Limit |
|----------|------------------|
| Simple API | 200-300M |
| Express + DB | 300-500M |
| Next.js | 400-600M |
| NestJS | 300-500M |
| Heavy processing | 1G-2G |

### Exponential Backoff (Recommended)

Prevents rapid crash loops from overwhelming your server:

```javascript
{
  exp_backoff_restart_delay: 100,
  // Restart delays: 100ms → 200ms → 400ms → 800ms → ... → 15000ms (cap)
  // Resets to 100ms after stable uptime
}
```

### Fixed Restart Delay

```javascript
{
  restart_delay: 4000,  // Always wait 4 seconds between restarts
}
```

### Max Restarts

```javascript
{
  max_restarts: 10,      // Stop trying after 10 rapid restarts
  min_uptime: '10s',     // "Rapid" = crashes within 10 seconds of start
}
```

### Scheduled Restart (Cron)

Useful for apps with memory leaks you haven't fixed yet:

```javascript
{
  cron_restart: '0 3 * * *',   // Restart every day at 3:00 AM
}
```

---

## Graceful Shutdown

When PM2 stops or restarts your app, it sends `SIGINT`. Your app should handle this to close connections properly.

### Node.js / Express

```javascript
const server = app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('Received SIGINT. Closing server...');
  server.close(() => {
    console.log('Server closed. Cleaning up...');
    // Close DB connections, Redis, etc.
    mongoose.connection.close();
    process.exit(0);
  });
});
```

### Next.js

Next.js handles shutdown internally. No custom code needed. Just set reasonable timeouts:

```javascript
{
  kill_timeout: 5000,
  listen_timeout: 15000,
}
```

### NestJS

```typescript
// main.ts
const app = await NestFactory.create(AppModule);
app.enableShutdownHooks();  // Required for PM2 graceful shutdown

// Lifecycle hooks in your service:
@Injectable()
export class AppService implements OnModuleDestroy {
  async onModuleDestroy() {
    // Clean up: close DB connections, clear intervals, etc.
    await this.prisma.$disconnect();
  }
}
```

### Ecosystem Config for Graceful Shutdown

```javascript
{
  kill_timeout: 5000,        // 5s for app to clean up after SIGINT
                              // After this, SIGKILL is sent (force kill)
  listen_timeout: 10000,     // 10s for new instance to start listening
                              // Used during reload/restart
  shutdown_with_message: false,  // Send SIGINT (default)
                                  // If true, sends process.send('shutdown')

  // For apps with slow startup (DB migrations, cache warming):
  wait_ready: true,          // Wait for process.send('ready')
  listen_timeout: 30000,     // Give 30s for startup
}
```

### Using `wait_ready` for Custom Startup

```javascript
// In your app — tell PM2 when you're actually ready
async function bootstrap() {
  await connectToDatabase();
  await warmCache();

  app.listen(port, () => {
    process.send('ready');  // Signal PM2 that startup is complete
  });
}
```

```javascript
// ecosystem.config.js
{
  wait_ready: true,
  listen_timeout: 30000,  // Max time to wait for 'ready' signal
}
```

---

## Watch Mode (Development)

> ⚠️ **Do NOT use watch in production.** It's for development only.

```javascript
// For development use ONLY
{
  watch: true,
  watch: ['src', 'config'],              // Directories to watch
  ignore_watch: [
    'node_modules',
    'logs',
    '.git',
    'uploads',
    '*.log',
  ],
  watch_options: {
    followSymlinks: false,
    usePolling: true,                     // Better for VMs/Docker
    interval: 1000,                       // Poll every 1 second
  },
}
```

---

## Running Multiple Apps on One VPS

### Multiple Apps in One Ecosystem File

```javascript
module.exports = {
  apps: [
    // Frontend: Next.js on port 3000
    {
      name: 'frontend',
      script: 'node_modules/next/dist/bin/next',
      args: 'start',
      cwd: '/var/www/apps/frontend',
      instances: 1,
      exec_mode: 'fork',
      env: { NODE_ENV: 'production', PORT: 3000 },
    },

    // Backend API: Express on port 4000
    {
      name: 'backend-api',
      script: 'dist/server.js',
      cwd: '/var/www/apps/backend',
      instances: 'max',
      exec_mode: 'cluster',
      env: { NODE_ENV: 'production', PORT: 4000 },
    },

    // Admin panel: Next.js on port 3001
    {
      name: 'admin',
      script: 'node_modules/next/dist/bin/next',
      args: 'start',
      cwd: '/var/www/apps/admin',
      instances: 1,
      exec_mode: 'fork',
      env: { NODE_ENV: 'production', PORT: 3001 },
    },

    // Background worker
    {
      name: 'worker',
      script: 'worker.js',
      cwd: '/var/www/apps/backend',
      instances: 1,
      exec_mode: 'fork',
      env: { NODE_ENV: 'production' },
    },
  ],
};
```

### Port Management

| App | Port | Nginx server_name |
|-----|------|-------------------|
| Frontend | 3000 | yourdomain.com |
| Backend API | 4000 | api.yourdomain.com |
| Admin | 3001 | admin.yourdomain.com |
| Worker | — | No Nginx needed |

### Separate Ecosystem Files

Alternatively, each app can have its own ecosystem file:

```bash
cd /var/www/apps/frontend && pm2 start ecosystem.config.js
cd /var/www/apps/backend && pm2 start ecosystem.config.js
cd /var/www/apps/admin && pm2 start ecosystem.config.js
pm2 save
```

---

## PM2 with Next.js — Complete Guide

### Standard Mode

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'myapp',
    script: 'node_modules/next/dist/bin/next',
    args: 'start',
    cwd: '/var/www/apps/myapp',
    instances: 1,
    exec_mode: 'fork',                // Next.js must use fork mode
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
    },
    max_memory_restart: '512M',
    exp_backoff_restart_delay: 100,
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    time: true,
  }],
};
```

### Standalone Mode (Recommended for Production)

Standalone mode creates a smaller, self-contained build:

```javascript
// next.config.js (or next.config.mjs)
module.exports = {
  output: 'standalone',
};
```

Build and copy static files:

```bash
npm run build

# Copy static assets to standalone directory
cp -r .next/static .next/standalone/.next/static
cp -r public .next/standalone/public
```

Ecosystem file for standalone:

```javascript
module.exports = {
  apps: [{
    name: 'myapp',
    script: '.next/standalone/server.js',
    cwd: '/var/www/apps/myapp',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      HOSTNAME: '0.0.0.0',      // Important: bind to all interfaces
    },
  }],
};
```

### Next.js Deployment Flow

```bash
cd /var/www/apps/myapp
git pull origin main
npm ci
npm run build

# If using standalone mode:
cp -r .next/static .next/standalone/.next/static
cp -r public .next/standalone/public

pm2 restart myapp --update-env
pm2 save
```

### Common Next.js + PM2 Issues

| Issue | Solution |
|-------|----------|
| Port already in use | `pm2 delete myapp` then start again |
| App only accessible from localhost | Set `HOSTNAME: '0.0.0.0'` in env |
| High memory on build | Add swap, use standalone mode |
| Cluster mode not working | Next.js only supports fork mode |
| `Cannot find module 'next'` | Run `npm install` in app directory |

---

## PM2 with NestJS — Complete Guide

### Basic Setup

```javascript
module.exports = {
  apps: [{
    name: 'myapi',
    script: 'dist/main.js',             // NestJS compiles to dist/
    cwd: '/var/www/apps/myapi',
    instances: 'max',                    // NestJS supports cluster mode
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
    },
    max_memory_restart: '500M',
    exp_backoff_restart_delay: 100,
    kill_timeout: 10000,                 // NestJS needs time for graceful shutdown
    merge_logs: true,
    time: true,
  }],
};
```

### NestJS main.ts for PM2

```typescript
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Enable shutdown hooks (critical for PM2 graceful reload)
  app.enableShutdownHooks();

  // Bind to all interfaces
  const port = process.env.PORT || 3000;
  await app.listen(port, '0.0.0.0');
  console.log(`Application running on port ${port}`);
}
bootstrap();
```

### NestJS Deployment Flow

```bash
cd /var/www/apps/myapi
git pull origin main
npm ci
npm run build          # Compiles TypeScript → dist/
pm2 reload myapi --update-env    # Zero-downtime reload
pm2 save
```

---

## PM2 with Express / Node.js API

### Basic Express Setup

```javascript
module.exports = {
  apps: [{
    name: 'myapi',
    script: 'app.js',                   // or server.js, index.js, src/index.js
    cwd: '/var/www/apps/myapi',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
    },
    max_memory_restart: '300M',
    exp_backoff_restart_delay: 100,
    merge_logs: true,
    time: true,
  }],
};
```

### Express Graceful Shutdown (Important for Cluster Reload)

```javascript
const app = require('./app');

const server = app.listen(process.env.PORT || 3000, () => {
  console.log(`Server running on port ${process.env.PORT || 3000}`);
});

// Graceful shutdown for PM2 reload
process.on('SIGINT', () => {
  server.close(() => {
    process.exit(0);
  });

  // Force close after 4 seconds
  setTimeout(() => {
    process.exit(1);
  }, 4000);
});
```

---

## PM2 Deploy (Built-in Deployment System)

PM2 has a built-in deployment system. This is an alternative to GitHub Actions.

### Setup

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'myapp',
    script: 'app.js',
    env: { NODE_ENV: 'production' },
  }],

  deploy: {
    production: {
      user: 'deploy',
      host: '123.45.67.89',
      ref: 'origin/main',
      repo: 'git@github.com:yourusername/yourrepo.git',
      path: '/var/www/apps/myapp',
      'pre-deploy': 'git fetch --all',
      'post-deploy': 'npm ci && npm run build && pm2 reload ecosystem.config.js --env production && pm2 save',
      'pre-setup': 'mkdir -p /var/www/apps/myapp',
    },
  },
};
```

### Commands

```bash
# First-time setup (from your local machine)
pm2 deploy production setup

# Deploy
pm2 deploy production

# Rollback to previous deployment
pm2 deploy production revert 1

# Execute a command on server
pm2 deploy production exec "pm2 logs"

# Get current commit
pm2 deploy production curr
```

---

## Cron & Scheduled Tasks with PM2

### Restart on Schedule

```javascript
{
  cron_restart: '0 3 * * *',    // Daily at 3:00 AM
}
```

### Run a Script on Schedule

```javascript
module.exports = {
  apps: [
    // Your main app
    {
      name: 'myapp',
      script: 'app.js',
    },

    // Cron job: cleanup old files daily at 2 AM
    {
      name: 'cleanup-cron',
      script: 'scripts/cleanup.js',
      cron_restart: '0 2 * * *',
      autorestart: false,        // Don't restart after it finishes
      watch: false,
    },

    // Cron job: send email digest every Monday at 9 AM
    {
      name: 'email-digest',
      script: 'scripts/send-digest.js',
      cron_restart: '0 9 * * 1',
      autorestart: false,
    },
  ],
};
```

---

## PM2 Modules & Plugins

### Built-in Modules

```bash
# Log rotation (essential)
pm2 install pm2-logrotate

# Server monitoring metrics
pm2 install pm2-server-monit

# List installed modules
pm2 ls
```

### Recommended Module Config

```bash
# pm2-logrotate
pm2 set pm2-logrotate:max_size 50M
pm2 set pm2-logrotate:retain 7
pm2 set pm2-logrotate:compress true
pm2 set pm2-logrotate:rotateInterval '0 0 * * *'
```

---

## Performance Tuning

### Node.js Memory Limits

By default, Node.js has a ~1.5GB heap limit. For large apps:

```javascript
{
  node_args: '--max-old-space-size=2048',   // 2GB heap
}
```

Or per-VPS size:

| VPS RAM | Recommended Heap | Setting |
|---------|-----------------|---------|
| 1GB | 512MB | `--max-old-space-size=512` |
| 2GB | 1024MB | `--max-old-space-size=1024` |
| 4GB | 2048MB | `--max-old-space-size=2048` |
| 8GB | 4096MB | `--max-old-space-size=4096` |

### Cluster Mode Optimization

```javascript
{
  instances: 'max',          // Use all CPU cores
  exec_mode: 'cluster',

  // For 2-core VPS, you might want:
  instances: 2,              // Match core count exactly

  // For 4+ cores, leave room for system:
  instances: -1,             // All cores minus 1
}
```

### Production Checklist

```javascript
module.exports = {
  apps: [{
    name: 'myapp',
    script: 'app.js',

    // ✅ Production settings
    watch: false,                        // Never watch in production
    autorestart: true,                   // Always auto-restart
    max_memory_restart: '500M',          // Prevent memory leaks
    exp_backoff_restart_delay: 100,      // Smart restart delay
    merge_logs: true,                    // Clean logs in cluster mode
    time: true,                          // Timestamp logs
    env: {
      NODE_ENV: 'production',            // Always set this
    },
  }],
};
```

---

## Troubleshooting

### App Won't Start

```bash
# Check logs for the error
pm2 logs myapp --lines 50

# Check if port is already in use
sudo ss -tulpn | grep :3000

# Try running the app directly (outside PM2) to see errors
cd /var/www/apps/myapp
node app.js
```

### App Keeps Restarting (Crash Loop)

```bash
# Check restart count
pm2 show myapp | grep restarts

# Check error logs
pm2 logs myapp --err --lines 100

# If min_uptime is too low, the app crashes before PM2 considers it "started"
# Fix: increase min_uptime or fix the underlying crash
```

### High Memory Usage

```bash
# Check current memory
pm2 monit

# Set a memory limit
# In ecosystem.config.js:
# max_memory_restart: '500M'

# Investigate with Node.js inspector
node --inspect app.js
# Connect Chrome DevTools to chrome://inspect
```

### "Error: listen EADDRINUSE"

```bash
# Port is already in use
sudo ss -tulpn | grep :3000

# Kill the process using the port
sudo kill -9 <PID>

# Or delete all PM2 processes and start fresh
pm2 delete all
pm2 start ecosystem.config.js
```

### PM2 Daemon Crashed

```bash
# Kill and restart PM2 daemon
pm2 kill
pm2 resurrect     # Restores saved process list

# If resurrect fails
pm2 start ecosystem.config.js
pm2 save
```

### Logs Not Appearing

```bash
# Check log file paths
pm2 show myapp | grep "log path"

# Make sure logs directory exists
mkdir -p /var/www/apps/myapp/logs

# Check permissions
ls -la /var/www/apps/myapp/logs/
```

### Environment Variables Not Updating

```bash
# Must use --update-env flag
pm2 restart myapp --update-env

# Verify env vars
pm2 env myapp
```

### Startup Not Working After Reboot

```bash
# Regenerate startup script
pm2 unstartup systemd
pm2 startup systemd
# Run the printed command

# Re-save process list
pm2 save
```

---

## Complete Configuration Reference

Every ecosystem config option at a glance:

```javascript
module.exports = {
  apps: [{
    // Identity
    name:               'myapp',
    script:             'app.js',
    args:               '--port 3000',
    cwd:                '/var/www/apps/myapp',
    interpreter:        'node',
    interpreter_args:   '',
    node_args:          '--max-old-space-size=1024',

    // Execution
    instances:          'max',        // 1, 2, 'max', -1
    exec_mode:          'cluster',    // 'fork' or 'cluster'

    // Environment
    env:                { NODE_ENV: 'production', PORT: 3000 },
    env_staging:        { NODE_ENV: 'staging', PORT: 3001 },

    // Restart
    autorestart:        true,
    watch:              false,
    max_restarts:       10,
    min_uptime:         '10s',
    restart_delay:      4000,
    exp_backoff_restart_delay: 100,
    max_memory_restart: '500M',
    cron_restart:       '0 3 * * *',

    // Logs
    error_file:         './logs/err.log',
    out_file:           './logs/out.log',
    log_file:           './logs/combined.log',
    log_date_format:    'YYYY-MM-DD HH:mm:ss Z',
    time:               true,
    merge_logs:         true,

    // Shutdown
    kill_timeout:       5000,
    listen_timeout:     10000,
    shutdown_with_message: false,
    wait_ready:         false,

    // Advanced
    source_map_support: true,
    treekill:           true,
    vizion:             true,
    force:              false,
  }],
};
```

---

## Quick Reference Cheatsheet

```bash
# ─── START / STOP ────────────────────────
pm2 start ecosystem.config.js    # Start from config
pm2 start app.js --name myapp    # Quick start
pm2 stop myapp                   # Stop
pm2 restart myapp                # Restart (brief downtime)
pm2 reload myapp                 # Reload (zero-downtime, cluster only)
pm2 delete myapp                 # Remove

# ─── STATUS / INFO ───────────────────────
pm2 list                         # List all processes
pm2 show myapp                   # Detailed info
pm2 monit                        # Interactive monitor

# ─── LOGS ────────────────────────────────
pm2 logs                         # All logs
pm2 logs myapp --lines 100       # Last 100 lines
pm2 flush                        # Clear all logs

# ─── SCALE ───────────────────────────────
pm2 scale myapp 4                # Scale to 4 instances
pm2 scale myapp +2               # Add 2 instances

# ─── ENVIRONMENT ─────────────────────────
pm2 restart myapp --update-env   # Apply new env vars
pm2 start ecosystem.config.js --env staging

# ─── PERSISTENCE ─────────────────────────
pm2 save                         # Save process list
pm2 startup                      # Auto-start on reboot
pm2 resurrect                    # Restore saved processes

# ─── MAINTENANCE ─────────────────────────
pm2 kill                         # Kill PM2 daemon
pm2 update                       # Update PM2 daemon
pm2 install pm2-logrotate        # Install log rotation
```

---

> **Ecosystem Config Templates:**
> [Node.js](ecosystem-nodejs.config.js) · [Next.js](ecosystem-nextjs.config.js) · [NestJS](ecosystem-nestjs.config.js)
>
> **Related Guides:**
> [Monitoring](../docs/MONITORING-GUIDE.md) · [Log Rotation](../docs/LOG-ROTATION-GUIDE.md) · [Swap Setup](../docs/SWAP-SETUP-GUIDE.md)
