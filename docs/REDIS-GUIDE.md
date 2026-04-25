# Redis Guide — In-Memory Data Store for VPS

> **Target OS:** Ubuntu 22.04 LTS VPS
> **Last Updated:** 2025
> **Part of:** [VPS Deployment Kit](../README.md)
> Related: [Database Guide](DATABASE-GUIDE.md) · [Firewall & Security Guide](FIREWALL-SECURITY-GUIDE.md) · [Docker Guide](../docker/DOCKER-GUIDE.md) · [PM2 Guide](../pm2/PM2-GUIDE.md)

Complete guide to installing, configuring, securing, and using Redis on an Ubuntu 22.04 VPS — covering caching, sessions, queues, pub/sub, and framework integrations.

---

## Table of Contents

1. [Installation](#1-installation)
2. [Configuration](#2-configuration)
3. [Security](#3-security)
4. [Persistence Strategies](#4-persistence-strategies)
5. [Common Use Cases](#5-common-use-cases)
6. [Framework Integration Examples](#6-framework-integration-examples)
7. [Redis CLI Cheatsheet](#7-redis-cli-cheatsheet)
8. [Monitoring](#8-monitoring)
9. [Docker Redis](#9-docker-redis)
10. [Backup & Restore](#10-backup--restore)
11. [Performance Tuning](#11-performance-tuning)
12. [Troubleshooting](#12-troubleshooting)
13. [Redis Cluster & Sentinel](#13-redis-cluster--sentinel)

---

## 1. Installation

### Install Redis on Ubuntu 22.04

```bash
# Update packages and install Redis
sudo apt update
sudo apt install redis-server -y

# Verify installation
redis-server --version
# redis-server v=7.0.x ...

redis-cli --version
# redis-cli 7.0.x

# Check the service is running
sudo systemctl status redis-server
```

### Enable on Boot

```bash
sudo systemctl enable redis-server
sudo systemctl start redis-server
```

### Verify Redis is Responding

```bash
redis-cli ping
# PONG
```

### Install a Newer Version (Optional)

If you need Redis 7.2+, use the official Redis repository:

```bash
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
sudo apt update
sudo apt install redis-server -y
```

---

## 2. Configuration

The main configuration file is `/etc/redis/redis.conf`. Always restart Redis after changes:

```bash
sudo systemctl restart redis-server
```

### Key Settings

```bash
sudo nano /etc/redis/redis.conf
```

#### Bind Address

```conf
# Listen on localhost only (default — most secure)
bind 127.0.0.1 ::1

# Listen on all interfaces (only if needed for remote access)
# bind 0.0.0.0
```

#### Password Authentication

```conf
# Set a strong password
requirepass your_super_strong_password_here
```

#### Memory Limits

```conf
# Set max memory (recommended: 25-50% of available RAM)
maxmemory 256mb

# Eviction policy when memory limit is reached
maxmemory-policy allkeys-lru
```

#### Persistence Settings

```conf
# --- RDB Snapshots ---
# Save after 3600 seconds if at least 1 key changed
# Save after 300 seconds if at least 100 keys changed
# Save after 60 seconds if at least 10000 keys changed
save 3600 1
save 300 100
save 60 10000

dbfilename dump.rdb
dir /var/lib/redis

# --- AOF (Append Only File) ---
appendonly yes
appendfilename "appendonly.aof"

# fsync policy: always | everysec | no
appendfsync everysec
```

#### Other Useful Settings

```conf
# Max connected clients
maxclients 10000

# Timeout for idle connections (0 = disabled)
timeout 300

# TCP keepalive
tcp-keepalive 300

# Log level: debug | verbose | notice | warning
loglevel notice
logfile /var/log/redis/redis-server.log

# Run as a daemon (already set by systemd)
supervised systemd
```

### Full Recommended Production Config Snippet

```conf
# /etc/redis/redis.conf — production overrides
bind 127.0.0.1 ::1
protected-mode yes
port 6379
requirepass your_super_strong_password_here

maxmemory 512mb
maxmemory-policy allkeys-lru

# Persistence: hybrid (RDB + AOF)
save 3600 1
save 300 100
save 60 10000
dbfilename dump.rdb

appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec

# Performance
tcp-keepalive 300
timeout 300
maxclients 10000

# Logging
loglevel notice
logfile /var/log/redis/redis-server.log

supervised systemd
```

---

## 3. Security

> **See also:** [Firewall & Security Guide](FIREWALL-SECURITY-GUIDE.md) for full UFW and Fail2Ban setup.

### 3.1 Password Authentication

Always set a password in production:

```conf
# /etc/redis/redis.conf
requirepass your_super_strong_password_here
```

Connect with password:

```bash
redis-cli -a your_super_strong_password_here
# or
redis-cli
AUTH your_super_strong_password_here
```

Generate a strong password:

```bash
openssl rand -base64 32
```

### 3.2 Bind to Localhost Only

```conf
bind 127.0.0.1 ::1
protected-mode yes
```

> **Never** expose Redis to the public internet without a VPN or SSH tunnel.

### 3.3 Rename Dangerous Commands

Disable or rename commands that can be destructive:

```conf
# /etc/redis/redis.conf
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command DEBUG ""
rename-command CONFIG "REDIS_CONFIG_a8f3b2"
rename-command SHUTDOWN "REDIS_SHUTDOWN_c4d9e1"
```

> Setting a command to `""` disables it entirely.

### 3.4 Firewall Rules (UFW)

```bash
# Redis should NOT be open to the internet
# Only allow from specific IPs if remote access is needed
sudo ufw deny 6379

# Allow from a specific app server IP (if Redis is on a separate host)
sudo ufw allow from 10.0.0.5 to any port 6379

# Verify
sudo ufw status
```

### 3.5 Disable Transparent Huge Pages (Performance + Security)

```bash
echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
```

Make it persistent — add to `/etc/rc.local` or create a systemd service:

```bash
cat <<'EOF' | sudo tee /etc/systemd/system/disable-thp.service
[Unit]
Description=Disable Transparent Huge Pages
Before=redis-server.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable disable-thp
```

### 3.6 Security Checklist

| Item | Status |
|---|---|
| `requirepass` set | ☐ |
| Bound to `127.0.0.1` only | ☐ |
| `protected-mode yes` | ☐ |
| Dangerous commands renamed/disabled | ☐ |
| UFW blocks port 6379 from public | ☐ |
| Redis not running as root | ☐ |
| THP disabled | ☐ |
| Strong password (32+ chars) | ☐ |

---

## 4. Persistence Strategies

### Overview

| Feature | RDB (Snapshotting) | AOF (Append Only File) |
|---|---|---|
| **How it works** | Point-in-time snapshots at intervals | Logs every write operation |
| **File** | `dump.rdb` | `appendonly.aof` |
| **Data loss risk** | Up to last snapshot interval | Minimal (depends on `appendfsync`) |
| **File size** | Compact | Larger (can be rewritten) |
| **Restart speed** | Fast (binary format) | Slower (replays operations) |
| **CPU impact** | Spikes during `BGSAVE` | Steady, lower impact |
| **Best for** | Backups, disaster recovery | Durability, minimal data loss |

### RDB Snapshots

```conf
# Trigger snapshot rules
save 3600 1     # Every hour if ≥1 change
save 300 100    # Every 5 min if ≥100 changes
save 60 10000   # Every 1 min if ≥10000 changes

dbfilename dump.rdb
dir /var/lib/redis

# Compression (recommended)
rdbcompression yes
rdbchecksum yes

# Stop accepting writes if RDB save fails
stop-writes-on-bgsave-error yes
```

Manual snapshot:

```bash
redis-cli BGSAVE
# or blocking:
redis-cli SAVE
```

### AOF (Append Only File)

```conf
appendonly yes
appendfilename "appendonly.aof"

# Sync policy:
# always    — every write (safest, slowest)
# everysec  — every second (good balance) ← RECOMMENDED
# no        — let OS decide (fastest, riskiest)
appendfsync everysec

# Auto-rewrite AOF when it grows too large
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
```

### Hybrid Approach (Recommended for Production)

Enable **both** RDB and AOF for the best balance:

```conf
# RDB for fast restarts and backups
save 3600 1
save 300 100
save 60 10000

# AOF for durability
appendonly yes
appendfsync everysec

# Use RDB preamble in AOF (Redis 7+)
aof-use-rdb-preamble yes
```

> With `aof-use-rdb-preamble yes`, Redis writes an RDB snapshot at the beginning of the AOF file during rewrites, combining fast loading with AOF durability.

### When to Use What

| Scenario | Strategy |
|---|---|
| Cache only (data is expendable) | RDB only, or persistence disabled |
| Session store | AOF with `everysec` |
| Job queues | AOF with `everysec` + RDB backups |
| Primary data store | Hybrid (RDB + AOF) |
| Maximum durability | AOF with `always` (performance tradeoff) |

### Disable Persistence Entirely

For pure caching where data loss is acceptable:

```conf
save ""
appendonly no
```

---

## 5. Common Use Cases

### 5.1 Session Storage

Store user sessions in Redis for fast access and shared state across multiple app servers.

```
User Request → App Server → Redis (session lookup) → Response
```

**Why Redis for sessions?**
- Sub-millisecond reads
- Automatic TTL expiration
- Shared across app instances / load balancers

### 5.2 Application Caching

Cache database queries, API responses, computed results.

```bash
# Cache a database query result for 5 minutes
SET user:1234:profile '{"name":"John","email":"john@example.com"}' EX 300
GET user:1234:profile
```

### 5.3 Job Queues

Redis-backed queues for background processing:

- **BullMQ** (Node.js) — robust queue with retries, delays, priorities
- **Laravel Horizon** — dashboard + queue workers for Laravel
- **Sidekiq** (Ruby) — background job processing

### 5.4 Rate Limiting

```bash
# Simple rate limiter: allow 100 requests per minute per IP
INCR rate:192.168.1.1
EXPIRE rate:192.168.1.1 60

# Check count
GET rate:192.168.1.1
```

### 5.5 Pub/Sub (Real-Time Messaging)

```bash
# Terminal 1: Subscribe to a channel
redis-cli SUBSCRIBE notifications

# Terminal 2: Publish a message
redis-cli PUBLISH notifications "New order #1234"
```

### 5.6 Leaderboards / Sorted Sets

```bash
ZADD leaderboard 1500 "player:alice"
ZADD leaderboard 2300 "player:bob"
ZADD leaderboard 1800 "player:charlie"

# Top 3 players
ZREVRANGE leaderboard 0 2 WITHSCORES
```

### 5.7 Distributed Locks

```bash
# Acquire lock (NX = only if not exists, EX = expire in 10s)
SET lock:order:1234 "worker-1" NX EX 10

# Release lock
DEL lock:order:1234
```

---

## 6. Framework Integration Examples

### 6.1 Laravel

#### `.env` Configuration

```env
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=your_super_strong_password_here
REDIS_PORT=6379

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
```

#### `config/database.php` — Redis Section

```php
'redis' => [

    'client' => env('REDIS_CLIENT', 'phpredis'), // or 'predis'

    'options' => [
        'cluster' => env('REDIS_CLUSTER', 'redis'),
        'prefix'  => env('REDIS_PREFIX', Str::slug(env('APP_NAME', 'laravel'), '_') . '_database_'),
    ],

    'default' => [
        'url'      => env('REDIS_URL'),
        'host'     => env('REDIS_HOST', '127.0.0.1'),
        'username' => env('REDIS_USERNAME'),
        'password' => env('REDIS_PASSWORD'),
        'port'     => env('REDIS_PORT', '6379'),
        'database' => env('REDIS_DB', '0'),
    ],

    'cache' => [
        'url'      => env('REDIS_URL'),
        'host'     => env('REDIS_HOST', '127.0.0.1'),
        'username' => env('REDIS_USERNAME'),
        'password' => env('REDIS_PASSWORD'),
        'port'     => env('REDIS_PORT', '6379'),
        'database' => env('REDIS_CACHE_DB', '1'),
    ],

],
```

#### Install phpredis Extension

```bash
sudo apt install php-redis -y
sudo systemctl restart php8.2-fpm
```

#### Usage in Laravel

```php
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Cache;

// Direct Redis usage
Redis::set('key', 'value');
$value = Redis::get('key');

// Cache facade (uses Redis driver)
Cache::put('users:count', User::count(), now()->addMinutes(10));
$count = Cache::get('users:count');

// Cache with remember pattern
$users = Cache::remember('users:all', 600, function () {
    return User::all();
});
```

#### Laravel Horizon (Queue Dashboard)

```bash
composer require laravel/horizon
php artisan horizon:install
php artisan horizon
```

> **See also:** [PM2 Guide](../pm2/PM2-GUIDE.md) for running Horizon with PM2 in production.

---

### 6.2 Node.js / Express

#### Install ioredis

```bash
npm install ioredis
```

#### Basic Connection

```js
// src/config/redis.js
const Redis = require('ioredis');

const redis = new Redis({
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_PASSWORD || undefined,
  maxRetriesPerRequest: 3,
  retryStrategy(times) {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
});

redis.on('connect', () => console.log('✅ Redis connected'));
redis.on('error', (err) => console.error('❌ Redis error:', err));

module.exports = redis;
```

#### Express Middleware — Caching

```js
// middleware/cache.js
const redis = require('../config/redis');

function cacheMiddleware(ttlSeconds = 300) {
  return async (req, res, next) => {
    const key = `cache:${req.originalUrl}`;
    try {
      const cached = await redis.get(key);
      if (cached) {
        return res.json(JSON.parse(cached));
      }
    } catch (err) {
      console.error('Cache read error:', err);
    }

    // Override res.json to cache the response
    const originalJson = res.json.bind(res);
    res.json = (data) => {
      redis.setex(key, ttlSeconds, JSON.stringify(data)).catch(console.error);
      return originalJson(data);
    };
    next();
  };
}

module.exports = cacheMiddleware;
```

#### Express Session with Redis

```bash
npm install express-session connect-redis ioredis
```

```js
const session = require('express-session');
const RedisStore = require('connect-redis').default;
const Redis = require('ioredis');

const redisClient = new Redis({
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: 6379,
  password: process.env.REDIS_PASSWORD,
});

app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 1000 * 60 * 60 * 24, // 24 hours
  },
}));
```

---

### 6.3 NestJS

#### Cache Manager with Redis

```bash
npm install @nestjs/cache-manager cache-manager cache-manager-ioredis-yet
```

```ts
// app.module.ts
import { Module } from '@nestjs/common';
import { CacheModule } from '@nestjs/cache-manager';
import { redisStore } from 'cache-manager-ioredis-yet';

@Module({
  imports: [
    CacheModule.registerAsync({
      isGlobal: true,
      useFactory: async () => ({
        store: await redisStore({
          host: process.env.REDIS_HOST || '127.0.0.1',
          port: parseInt(process.env.REDIS_PORT || '6379'),
          password: process.env.REDIS_PASSWORD,
          ttl: 300, // default TTL in seconds
        }),
      }),
    }),
  ],
})
export class AppModule {}
```

#### Using Cache in a Service

```ts
import { Injectable, Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';

@Injectable()
export class UsersService {
  constructor(@Inject(CACHE_MANAGER) private cache: Cache) {}

  async getUsers() {
    const cached = await this.cache.get('users');
    if (cached) return cached;

    const users = await this.fetchUsersFromDb();
    await this.cache.set('users', users, 600);
    return users;
  }
}
```

#### BullMQ Queues with NestJS

```bash
npm install @nestjs/bullmq bullmq
```

```ts
// app.module.ts
import { BullModule } from '@nestjs/bullmq';

@Module({
  imports: [
    BullModule.forRoot({
      connection: {
        host: process.env.REDIS_HOST || '127.0.0.1',
        port: parseInt(process.env.REDIS_PORT || '6379'),
        password: process.env.REDIS_PASSWORD,
      },
    }),
    BullModule.registerQueue({ name: 'email' }),
  ],
})
export class AppModule {}
```

```ts
// email.processor.ts
import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';

@Processor('email')
export class EmailProcessor extends WorkerHost {
  async process(job: Job) {
    console.log(`Sending email to ${job.data.to}`);
    // ... send email logic
  }
}
```

```ts
// email.service.ts — adding jobs to the queue
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Injectable()
export class EmailService {
  constructor(@InjectQueue('email') private emailQueue: Queue) {}

  async sendWelcomeEmail(userId: string) {
    await this.emailQueue.add('welcome', { userId }, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 1000 },
    });
  }
}
```

---

### 6.4 Next.js

#### API Route Caching with ioredis

```bash
npm install ioredis
```

```ts
// lib/redis.ts
import Redis from 'ioredis';

const redis = new Redis({
  host: process.env.REDIS_HOST || '127.0.0.1',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD,
});

export default redis;
```

#### App Router — Route Handler with Cache

```ts
// app/api/products/route.ts
import { NextResponse } from 'next/server';
import redis from '@/lib/redis';

export async function GET() {
  const cacheKey = 'products:all';

  // Check cache first
  const cached = await redis.get(cacheKey);
  if (cached) {
    return NextResponse.json(JSON.parse(cached));
  }

  // Fetch from database
  const products = await fetchProductsFromDb();

  // Cache for 5 minutes
  await redis.setex(cacheKey, 300, JSON.stringify(products));

  return NextResponse.json(products);
}
```

#### Cache Invalidation Helper

```ts
// lib/cache.ts
import redis from './redis';

export async function invalidateCache(pattern: string) {
  const keys = await redis.keys(pattern);
  if (keys.length > 0) {
    await redis.del(...keys);
  }
}

// Usage: after updating a product
await invalidateCache('products:*');
```

---

## 7. Redis CLI Cheatsheet

### Connection

```bash
redis-cli                           # Connect to localhost:6379
redis-cli -h 10.0.0.5 -p 6379      # Connect to remote host
redis-cli -a your_password           # Connect with password
redis-cli -n 2                       # Connect to database 2
redis-cli --tls                      # Connect with TLS
```

### Strings

```bash
SET key "value"                      # Set a key
SET key "value" EX 300               # Set with 5-min expiry
GET key                              # Get value
MSET k1 "v1" k2 "v2"                # Set multiple keys
MGET k1 k2                          # Get multiple keys
INCR counter                        # Increment by 1
INCRBY counter 10                   # Increment by 10
DECR counter                        # Decrement by 1
APPEND key " more"                  # Append to value
STRLEN key                          # Length of value
SETNX key "value"                   # Set only if not exists
```

### Keys & Expiry

```bash
KEYS *                               # List all keys (⚠️ avoid in production)
SCAN 0 MATCH "user:*" COUNT 100     # Safe iteration over keys
EXISTS key                           # Check if key exists (returns 1/0)
DEL key1 key2                        # Delete keys
UNLINK key1 key2                    # Async delete (non-blocking)
TYPE key                             # Get key type
TTL key                              # Time to live in seconds
PTTL key                             # Time to live in milliseconds
EXPIRE key 300                       # Set expiry (seconds)
PERSIST key                          # Remove expiry
RENAME key newkey                    # Rename a key
```

### Hashes

```bash
HSET user:1 name "John" email "j@x.com"   # Set hash fields
HGET user:1 name                           # Get one field
HGETALL user:1                             # Get all fields
HDEL user:1 email                          # Delete a field
HEXISTS user:1 name                        # Check field exists
HINCRBY user:1 visits 1                    # Increment field
```

### Lists

```bash
LPUSH queue "job1"                   # Push to head
RPUSH queue "job2"                   # Push to tail
LPOP queue                           # Pop from head
RPOP queue                           # Pop from tail
LRANGE queue 0 -1                    # Get all items
LLEN queue                           # List length
```

### Sets

```bash
SADD tags "redis" "cache" "fast"     # Add members
SMEMBERS tags                        # Get all members
SISMEMBER tags "redis"               # Check membership
SCARD tags                           # Count members
SREM tags "fast"                     # Remove member
```

### Sorted Sets

```bash
ZADD scores 100 "alice" 200 "bob"    # Add with scores
ZRANGE scores 0 -1 WITHSCORES       # Get all (ascending)
ZREVRANGE scores 0 -1 WITHSCORES    # Get all (descending)
ZRANK scores "alice"                 # Get rank (0-based)
ZSCORE scores "alice"                # Get score
ZRANGEBYSCORE scores 50 150          # Get by score range
```

### Server & Database

```bash
INFO                                 # Server info (all sections)
INFO memory                          # Memory usage info
INFO keyspace                        # Database key counts
DBSIZE                               # Key count in current DB
SELECT 1                             # Switch to database 1
FLUSHDB                              # ⚠️ Delete all keys in current DB
FLUSHALL                             # ⚠️ Delete all keys in ALL DBs
MONITOR                              # Real-time command stream (Ctrl+C to stop)
SLOWLOG GET 10                       # Last 10 slow queries
CLIENT LIST                          # Connected clients
CONFIG GET maxmemory                 # Get config value
CONFIG SET maxmemory 512mb           # Set config at runtime
BGSAVE                               # Trigger RDB snapshot
LASTSAVE                             # Timestamp of last save
```

---

## 8. Monitoring

### Quick Health Check

```bash
redis-cli ping
# PONG

redis-cli INFO server | grep -E "redis_version|uptime|connected_clients"
```

### Memory Usage

```bash
redis-cli INFO memory
```

Key fields to watch:

| Field | What It Means |
|---|---|
| `used_memory_human` | Total memory used by Redis |
| `used_memory_peak_human` | Peak memory usage |
| `used_memory_rss_human` | Memory as seen by OS (includes fragmentation) |
| `mem_fragmentation_ratio` | Ideally ~1.0. >1.5 = fragmentation issue |
| `maxmemory_human` | Configured memory limit |
| `evicted_keys` | Keys removed due to maxmemory policy |

### Memory Usage per Key

```bash
redis-cli MEMORY USAGE mykey
# (integer) 72  — bytes used by this key

# Top keys by memory (requires redis-cli 7+)
redis-cli --memkeys
```

### Slow Log

```bash
# Configure slow log threshold (microseconds, default: 10000 = 10ms)
redis-cli CONFIG SET slowlog-log-slower-than 5000
redis-cli CONFIG SET slowlog-max-len 128

# View slow queries
redis-cli SLOWLOG GET 10
redis-cli SLOWLOG LEN
redis-cli SLOWLOG RESET
```

### Latency Monitoring

```bash
# Continuous latency test
redis-cli --latency
# min: 0, max: 1, avg: 0.25 (1523 samples)

# Latency over time
redis-cli --latency-history -i 15

# Intrinsic latency test (measures system, not Redis)
redis-cli --intrinsic-latency 5
```

### Real-Time Command Monitoring

```bash
# Watch all commands in real time (⚠️ impacts performance)
redis-cli MONITOR

# Better: use SLOWLOG instead of MONITOR in production
```

### Keyspace & Client Info

```bash
redis-cli INFO keyspace
# db0:keys=1234,expires=567,avg_ttl=45321

redis-cli INFO clients
# connected_clients:15
# blocked_clients:0

redis-cli CLIENT LIST
```

### Automated Monitoring Script

```bash
#!/bin/bash
# redis-health.sh — Quick Redis health report

echo "=== Redis Health Check ==="
echo ""

echo "--- Connection ---"
redis-cli -a "${REDIS_PASSWORD}" ping

echo ""
echo "--- Memory ---"
redis-cli -a "${REDIS_PASSWORD}" INFO memory | grep -E "used_memory_human|used_memory_peak_human|maxmemory_human|mem_fragmentation_ratio|evicted_keys"

echo ""
echo "--- Keyspace ---"
redis-cli -a "${REDIS_PASSWORD}" INFO keyspace

echo ""
echo "--- Clients ---"
redis-cli -a "${REDIS_PASSWORD}" INFO clients | grep -E "connected_clients|blocked_clients"

echo ""
echo "--- Slow Log (last 5) ---"
redis-cli -a "${REDIS_PASSWORD}" SLOWLOG GET 5
```

> **See also:** [Monitoring Guide](MONITORING-GUIDE.md) for system-wide monitoring setup.

---

## 9. Docker Redis

> **See also:** [Docker Guide](../docker/DOCKER-GUIDE.md) for full Docker and Docker Compose setup.

### Docker Compose Service

```yaml
# docker-compose.yml
services:
  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - redis_data:/data
      - ./redis/redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

volumes:
  redis_data:

networks:
  app-network:
    driver: bridge
```

### Custom redis.conf for Docker

```conf
# redis/redis.conf
bind 0.0.0.0
protected-mode no
port 6379
requirepass your_super_strong_password_here

maxmemory 256mb
maxmemory-policy allkeys-lru

# Persistence
save 3600 1
save 300 100
save 60 10000

appendonly yes
appendfsync everysec
aof-use-rdb-preamble yes

# Logging
loglevel notice
```

> **Note:** `bind 0.0.0.0` and `protected-mode no` are acceptable inside Docker because access is restricted by Docker networking and port binding to `127.0.0.1`.

### Full Stack Example

```yaml
# docker-compose.yml — App + Redis + DB
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "127.0.0.1:6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pg_data:/var/lib/postgresql/data
    networks:
      - app-network

volumes:
  redis_data:
  pg_data:

networks:
  app-network:
    driver: bridge
```

### Docker Redis Commands

```bash
# Start Redis container
docker compose up -d redis

# Connect to Redis CLI inside container
docker compose exec redis redis-cli -a your_password

# View logs
docker compose logs -f redis

# Check memory usage
docker compose exec redis redis-cli -a your_password INFO memory

# Backup data
docker compose exec redis redis-cli -a your_password BGSAVE
docker cp $(docker compose ps -q redis):/data/dump.rdb ./backups/
```

---

## 10. Backup & Restore

> **See also:** [Database Guide](DATABASE-GUIDE.md) for MySQL/PostgreSQL backup strategies.

### Backup the RDB File

```bash
# Trigger a background save
redis-cli -a your_password BGSAVE

# Wait for save to complete
redis-cli -a your_password LASTSAVE

# Copy the dump file
sudo cp /var/lib/redis/dump.rdb /backups/redis/dump-$(date +%Y%m%d-%H%M%S).rdb
```

### Backup the AOF File

```bash
# Trigger AOF rewrite to compact the file
redis-cli -a your_password BGREWRITEAOF

# Copy the AOF file
sudo cp /var/lib/redis/appendonly.aof /backups/redis/appendonly-$(date +%Y%m%d-%H%M%S).aof
```

### Restore from Backup

```bash
# 1. Stop Redis
sudo systemctl stop redis-server

# 2. Copy backup file to Redis data directory
sudo cp /backups/redis/dump-20250101-120000.rdb /var/lib/redis/dump.rdb
sudo chown redis:redis /var/lib/redis/dump.rdb

# 3. If restoring AOF, copy that too
sudo cp /backups/redis/appendonly.aof /var/lib/redis/appendonly.aof
sudo chown redis:redis /var/lib/redis/appendonly.aof

# 4. Start Redis
sudo systemctl start redis-server

# 5. Verify
redis-cli -a your_password DBSIZE
```

### Automated Backup Script

```bash
#!/bin/bash
# /usr/local/bin/redis-backup.sh

REDIS_PASSWORD="your_password"
BACKUP_DIR="/backups/redis"
REDIS_DATA_DIR="/var/lib/redis"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

# Trigger save
redis-cli -a "$REDIS_PASSWORD" BGSAVE 2>/dev/null
sleep 5

# Copy RDB
if [ -f "$REDIS_DATA_DIR/dump.rdb" ]; then
    cp "$REDIS_DATA_DIR/dump.rdb" "$BACKUP_DIR/dump-${DATE}.rdb"
    echo "[$(date)] RDB backup: dump-${DATE}.rdb"
fi

# Copy AOF (if exists)
if [ -f "$REDIS_DATA_DIR/appendonly.aof" ]; then
    cp "$REDIS_DATA_DIR/appendonly.aof" "$BACKUP_DIR/appendonly-${DATE}.aof"
    echo "[$(date)] AOF backup: appendonly-${DATE}.aof"
fi

# Remove backups older than retention period
find "$BACKUP_DIR" -name "*.rdb" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.aof" -mtime +$RETENTION_DAYS -delete

echo "[$(date)] Redis backup complete. Old backups (>$RETENTION_DAYS days) removed."
```

Set up the cron job:

```bash
chmod +x /usr/local/bin/redis-backup.sh

# Run daily at 2 AM
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/redis-backup.sh >> /var/log/redis-backup.log 2>&1") | crontab -
```

### Remote Backup (to another server)

```bash
# Rsync to remote backup server
rsync -avz /backups/redis/ backup-user@backup-server:/backups/redis/
```

---

## 11. Performance Tuning

### Connection Pooling

Don't create a new Redis connection per request. Use a shared connection or pool.

**Node.js (ioredis):**

```js
// ioredis maintains a single connection with automatic pipelining
const Redis = require('ioredis');

// Single connection (good for most apps)
const redis = new Redis({ host: '127.0.0.1', port: 6379 });

// Cluster mode handles connection pooling automatically
const cluster = new Redis.Cluster([
  { host: '127.0.0.1', port: 6380 },
  { host: '127.0.0.1', port: 6381 },
]);
```

**Laravel (config/database.php):**

```php
// Laravel manages connections via the Redis facade
// phpredis extension is faster than predis
'client' => 'phpredis',
```

### Pipelining (Batch Commands)

Send multiple commands without waiting for individual responses:

```js
// Node.js — pipeline
const pipeline = redis.pipeline();
pipeline.set('key1', 'value1');
pipeline.set('key2', 'value2');
pipeline.get('key1');
pipeline.get('key2');
const results = await pipeline.exec();
// results: [[null, 'OK'], [null, 'OK'], [null, 'value1'], [null, 'value2']]
```

```bash
# redis-cli pipeline
redis-cli --pipe <<EOF
SET key1 value1
SET key2 value2
GET key1
EOF
```

### Maxmemory Policies Explained

| Policy | Behavior | Best For |
|---|---|---|
| `noeviction` | Returns error on write when memory full | Data must never be lost |
| `allkeys-lru` | Evicts least recently used key (any key) | **General-purpose caching** ← Most common |
| `allkeys-lfu` | Evicts least frequently used key (any key) | Caching with hot/cold data patterns |
| `allkeys-random` | Evicts a random key | When all keys have equal importance |
| `volatile-lru` | Evicts LRU key **with an expiry set** | Mix of persistent + cache keys |
| `volatile-lfu` | Evicts LFU key **with an expiry set** | Mix of persistent + cache keys |
| `volatile-random` | Evicts random key **with an expiry set** | Mix of persistent + cache keys |
| `volatile-ttl` | Evicts key with shortest TTL | When TTL indicates priority |

> **Recommendation:** Use `allkeys-lru` for caching workloads. Use `noeviction` if Redis is your primary data store.

### Use UNLINK Instead of DEL

```bash
# DEL blocks Redis until keys are removed
DEL large_key

# UNLINK removes keys asynchronously (non-blocking)
UNLINK large_key
```

### Use SCAN Instead of KEYS

```bash
# ❌ KEYS blocks Redis — never use in production
KEYS user:*

# ✅ SCAN iterates safely without blocking
SCAN 0 MATCH "user:*" COUNT 100
```

### Avoid Large Keys

| Issue | Solution |
|---|---|
| Single key >1 MB | Split into smaller keys or use hashes |
| List with millions of items | Partition into multiple lists |
| Large hash | Use multiple smaller hashes |

### System-Level Tuning

```bash
# Increase max open files
echo "redis soft nofile 65535" | sudo tee -a /etc/security/limits.conf
echo "redis hard nofile 65535" | sudo tee -a /etc/security/limits.conf

# TCP backlog (for high connection rates)
echo "net.core.somaxconn = 65535" | sudo tee -a /etc/sysctl.conf
echo "vm.overcommit_memory = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Disable THP (see Security section)
echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
```

---

## 12. Troubleshooting

### Connection Refused

```
Error: connect ECONNREFUSED 127.0.0.1:6379
```

**Fix:**

```bash
# Check if Redis is running
sudo systemctl status redis-server

# Start if stopped
sudo systemctl start redis-server

# Check what port/address Redis is listening on
sudo ss -tlnp | grep redis

# Check Redis logs
sudo tail -50 /var/log/redis/redis-server.log
```

### Authentication Error

```
NOAUTH Authentication required
(error) ERR AUTH <error> ERR Client sent AUTH, but no password is set
```

**Fix:**

```bash
# Connect with password
redis-cli -a your_password

# Or check if password is set
grep "requirepass" /etc/redis/redis.conf
```

### OOM (Out of Memory)

```
OOM command not allowed when used memory > 'maxmemory'
```

**Fix:**

```bash
# Check current memory usage
redis-cli INFO memory | grep used_memory_human

# Increase maxmemory
redis-cli CONFIG SET maxmemory 512mb

# Set an eviction policy
redis-cli CONFIG SET maxmemory-policy allkeys-lru

# Make persistent
sudo nano /etc/redis/redis.conf
# maxmemory 512mb
# maxmemory-policy allkeys-lru
sudo systemctl restart redis-server
```

### Slow Queries

```bash
# Check slow log
redis-cli SLOWLOG GET 10

# Common causes:
# 1. KEYS * command — replace with SCAN
# 2. Large DEL operations — use UNLINK
# 3. Saving large RDB — check BGSAVE timing
# 4. Lua scripts blocking — optimize or break up
```

### High Memory Fragmentation

```bash
redis-cli INFO memory | grep mem_fragmentation_ratio
# If ratio > 1.5, you have fragmentation

# Fix: restart Redis to defragment
sudo systemctl restart redis-server

# Or enable active defragmentation (Redis 4+)
redis-cli CONFIG SET activedefrag yes
```

### Redis Won't Start

```bash
# Check for config errors
redis-server --test-memory 256
redis-server /etc/redis/redis.conf --loglevel debug

# Common causes:
# - Corrupted RDB/AOF file
# - Permission issues on data directory
# - Port already in use

# Fix corrupted AOF
redis-check-aof --fix /var/lib/redis/appendonly.aof

# Fix permissions
sudo chown -R redis:redis /var/lib/redis
sudo chmod 750 /var/lib/redis
```

### Too Many Connections

```
ERR max number of clients reached
```

**Fix:**

```bash
# Check connected clients
redis-cli CLIENT LIST | wc -l

# Increase limit
redis-cli CONFIG SET maxclients 20000

# Find and close idle connections
redis-cli CLIENT LIST | grep "idle="
redis-cli CLIENT KILL ID <client-id>

# Set timeout for idle connections
redis-cli CONFIG SET timeout 300
```

### Quick Diagnostic Commands

```bash
# Full health check in one command
redis-cli INFO | grep -E "redis_version|uptime_in_days|connected_clients|used_memory_human|maxmemory_human|evicted_keys|keyspace_hits|keyspace_misses|mem_fragmentation_ratio"

# Hit rate calculation
redis-cli INFO stats | grep -E "keyspace_hits|keyspace_misses"
# hit_rate = hits / (hits + misses) — aim for >90%
```

---

## 13. Redis Cluster & Sentinel

### When to Use What

| Setup | Use Case | Min Nodes |
|---|---|---|
| **Standalone** | Small-medium apps, single VPS | 1 |
| **Sentinel** | High availability, automatic failover | 3 (1 master + 2 replicas + 3 sentinels) |
| **Cluster** | Horizontal scaling, large datasets | 6 (3 masters + 3 replicas) |

### Redis Sentinel (High Availability)

Sentinel monitors Redis instances and performs automatic failover.

```
┌─────────┐     ┌─────────┐     ┌─────────┐
│Sentinel 1│     │Sentinel 2│     │Sentinel 3│
└────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │
     ▼                ▼                ▼
┌─────────┐     ┌─────────┐     ┌─────────┐
│  Master  │────▶│ Replica 1│     │ Replica 2│
│  :6379   │     │  :6380   │     │  :6381   │
└──────────┘     └──────────┘     └──────────┘
```

**Sentinel config:**

```conf
# /etc/redis/sentinel.conf
port 26379
sentinel monitor mymaster 127.0.0.1 6379 2
sentinel auth-pass mymaster your_password
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 10000
sentinel parallel-syncs mymaster 1
```

```bash
# Start sentinel
redis-sentinel /etc/redis/sentinel.conf

# Check master status
redis-cli -p 26379 SENTINEL masters
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
```

**Node.js with Sentinel (ioredis):**

```js
const Redis = require('ioredis');

const redis = new Redis({
  sentinels: [
    { host: '10.0.0.1', port: 26379 },
    { host: '10.0.0.2', port: 26379 },
    { host: '10.0.0.3', port: 26379 },
  ],
  name: 'mymaster',
  password: 'your_password',
});
```

### Redis Cluster (Horizontal Scaling)

Cluster automatically shards data across multiple nodes.

```bash
# Create a cluster (3 masters + 3 replicas)
redis-cli --cluster create \
  10.0.0.1:6379 10.0.0.2:6379 10.0.0.3:6379 \
  10.0.0.4:6379 10.0.0.5:6379 10.0.0.6:6379 \
  --cluster-replicas 1 -a your_password
```

**Node.js with Cluster (ioredis):**

```js
const Redis = require('ioredis');

const cluster = new Redis.Cluster([
  { host: '10.0.0.1', port: 6379 },
  { host: '10.0.0.2', port: 6379 },
  { host: '10.0.0.3', port: 6379 },
], {
  redisOptions: { password: 'your_password' },
  scaleReads: 'slave',
});
```

### Decision Guide

```
Start here
   │
   ▼
Single VPS, <10GB data?
   ├── YES → Standalone Redis (this guide)
   │
   ▼
Need automatic failover?
   ├── YES → Redis Sentinel
   │
   ▼
Need to scale beyond single-server RAM?
   ├── YES → Redis Cluster
   │
   ▼
Consider managed Redis:
   - AWS ElastiCache
   - DigitalOcean Managed Redis
   - Redis Cloud
```

> **For most VPS deployments covered by this kit, standalone Redis with proper persistence and backups is sufficient.**

---

## Quick Reference

### Essential Commands After Install

```bash
# 1. Set a password
sudo sed -i 's/# requirepass foobared/requirepass YOUR_STRONG_PASSWORD/' /etc/redis/redis.conf

# 2. Bind to localhost
sudo sed -i 's/^bind .*/bind 127.0.0.1 ::1/' /etc/redis/redis.conf

# 3. Enable AOF persistence
sudo sed -i 's/appendonly no/appendonly yes/' /etc/redis/redis.conf

# 4. Set memory limit
echo "maxmemory 256mb" | sudo tee -a /etc/redis/redis.conf
echo "maxmemory-policy allkeys-lru" | sudo tee -a /etc/redis/redis.conf

# 5. Restart
sudo systemctl restart redis-server

# 6. Verify
redis-cli -a YOUR_STRONG_PASSWORD ping
```

### Environment Variables Template

```env
# .env — Redis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=your_super_strong_password_here
REDIS_DB=0

# Laravel-specific
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Node.js / NestJS / Next.js
REDIS_URL=redis://:your_super_strong_password_here@127.0.0.1:6379/0
```

---

*Part of the [VPS Deployment Kit](../README.md) — see also [Database Guide](DATABASE-GUIDE.md) · [Firewall & Security Guide](FIREWALL-SECURITY-GUIDE.md) · [Docker Guide](../docker/DOCKER-GUIDE.md) · [PM2 Guide](../pm2/PM2-GUIDE.md)*
