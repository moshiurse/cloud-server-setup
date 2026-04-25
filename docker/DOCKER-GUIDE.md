# Docker Deployment Guide for VPS

> A comprehensive guide to deploying web applications on a VPS using Docker. Part of the [VPS Deployment Kit](../README.md).

---

## Table of Contents

1. [Why Docker for VPS Deployment](#1-why-docker-for-vps-deployment)
2. [Prerequisites](#2-prerequisites)
3. [Quick Start — Deploy Any Project](#3-quick-start--deploy-any-project)
4. [Docker Concepts Explained](#4-docker-concepts-explained)
5. [Dockerfile Best Practices](#5-dockerfile-best-practices)
6. [Docker Compose Deep Dive](#6-docker-compose-deep-dive)
7. [Networking — Docker + Nginx + SSL](#7-networking--docker--nginx--ssl)
8. [Database Management with Docker](#8-database-management-with-docker)
9. [Common Docker Commands](#9-common-docker-commands)
10. [Docker Deployment Workflow](#10-docker-deployment-workflow)
11. [Monitoring Docker Containers](#11-monitoring-docker-containers)
12. [Troubleshooting](#12-troubleshooting)
13. [.dockerignore Templates](#13-dockerignore-templates)
14. [Docker vs PM2 — When to Use What](#14-docker-vs-pm2--when-to-use-what)

---

## 1. Why Docker for VPS Deployment

| Problem | Docker Solution |
|---|---|
| "Works on my machine" | Same image runs everywhere — dev, staging, production |
| Dependency conflicts between apps | Each app is fully isolated in its own container |
| Painful server setup | One `docker compose up` replaces 20 manual install steps |
| Scaling a single app | Scale horizontally: `docker compose up --scale app=3` |
| Rollback after bad deploy | Keep the previous image, roll back in seconds |
| OS-level package drift | Pin exact versions in your Dockerfile |

**Bottom line:** Docker makes deployments reproducible, isolated, and reversible. If you run more than one app on a VPS, or work on a team, Docker pays for itself immediately.

---

## 2. Prerequisites

### Install Docker on Ubuntu 22.04

```bash
# Remove old/unofficial Docker packages
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null

# Install dependencies
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker CE + Compose plugin
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Post-Install Setup

```bash
# Add your user to the docker group (no more sudo for docker commands)
sudo usermod -aG docker $USER

# Apply group change (or log out and back in)
newgrp docker

# Verify installation
docker --version
docker compose version
docker run hello-world
```

### Docker Resource Management on Low-RAM VPS

For VPS with 1–2 GB RAM, configure Docker to be memory-aware:

```bash
# Check available memory
free -h

# Set default memory limits in daemon config
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "memlock": { "Name": "memlock", "Hard": -1, "Soft": -1 }
  }
}
EOF

sudo systemctl restart docker
```

> **💡 Tip:** On a 1 GB VPS, avoid running MySQL + Redis + your app simultaneously. Use SQLite or an external managed database instead. See the [resource limits section](#resource-limits) in Docker Compose Deep Dive.

---

## 3. Quick Start — Deploy Any Project

All examples assume:
- Your project is at `/var/www/apps/yourapp`
- You've already run `vps-setup.sh` (see [VPS Setup Guide](../DEPLOYMENT-GUIDE.md))
- Files referenced below are in this repo under `docker/`

### PHP

```bash
cd /var/www/apps/yourapp

# Copy configs from this kit
cp /path/to/vps-deployment-kit/docker/dockerfiles/Dockerfile.php ./Dockerfile
cp /path/to/vps-deployment-kit/docker/compose/docker-compose.php.yml ./docker-compose.yml
mkdir -p docker/nginx
cp /path/to/vps-deployment-kit/docker/nginx/nginx-docker-php.conf ./docker/nginx/default.conf

# Configure environment
cp .env.example .env
nano .env

# Launch
docker compose up -d
```

> **📁 Files:** [`Dockerfile.php`](dockerfiles/Dockerfile.php) · [`docker-compose.php.yml`](compose/docker-compose.php.yml) · [`nginx-docker-php.conf`](nginx/nginx-docker-php.conf)

### Laravel

```bash
cd /var/www/apps/yourapp

cp /path/to/vps-deployment-kit/docker/dockerfiles/Dockerfile.laravel ./Dockerfile
cp /path/to/vps-deployment-kit/docker/compose/docker-compose.laravel.yml ./docker-compose.yml
mkdir -p docker/nginx
cp /path/to/vps-deployment-kit/docker/nginx/nginx-docker-laravel.conf ./docker/nginx/default.conf

cp .env.example .env
nano .env

docker compose up -d

# Laravel-specific setup
docker compose exec app php artisan key:generate
docker compose exec app php artisan migrate
docker compose exec app php artisan storage:link
```

> **📁 Files:** [`Dockerfile.laravel`](dockerfiles/Dockerfile.laravel) · [`docker-compose.laravel.yml`](compose/docker-compose.laravel.yml) · [`nginx-docker-laravel.conf`](nginx/nginx-docker-laravel.conf)

### Node.js (Express / Fastify / Koa)

```bash
cd /var/www/apps/yourapp

cp /path/to/vps-deployment-kit/docker/dockerfiles/Dockerfile.nodejs ./Dockerfile
cp /path/to/vps-deployment-kit/docker/compose/docker-compose.nodejs.yml ./docker-compose.yml
mkdir -p docker/nginx
cp /path/to/vps-deployment-kit/docker/nginx/nginx-docker-node.conf ./docker/nginx/default.conf

cp .env.example .env
nano .env

docker compose up -d
```

> **📁 Files:** [`Dockerfile.nodejs`](dockerfiles/Dockerfile.nodejs) · [`docker-compose.nodejs.yml`](compose/docker-compose.nodejs.yml) · [`nginx-docker-node.conf`](nginx/nginx-docker-node.conf)

### Next.js

**⚠️ Important:** You must set `output: 'standalone'` in your `next.config.js` before building:

```js
// next.config.js
module.exports = {
  output: 'standalone',
};
```

This enables Next.js to produce a self-contained server that doesn't need `node_modules` at runtime, resulting in much smaller Docker images (~100 MB vs ~1 GB).

```bash
cd /var/www/apps/yourapp

cp /path/to/vps-deployment-kit/docker/dockerfiles/Dockerfile.nextjs ./Dockerfile
cp /path/to/vps-deployment-kit/docker/compose/docker-compose.nextjs.yml ./docker-compose.yml
mkdir -p docker/nginx
cp /path/to/vps-deployment-kit/docker/nginx/nginx-docker-node.conf ./docker/nginx/default.conf

cp .env.example .env
nano .env

docker compose up -d
```

> **📁 Files:** [`Dockerfile.nextjs`](dockerfiles/Dockerfile.nextjs) · [`docker-compose.nextjs.yml`](compose/docker-compose.nextjs.yml) · [`nginx-docker-node.conf`](nginx/nginx-docker-node.conf)

### React (CRA / Vite)

React builds into static files — no Node.js runtime needed. The Dockerfile builds your app and serves it with Nginx directly.

```bash
cd /var/www/apps/yourapp

cp /path/to/vps-deployment-kit/docker/dockerfiles/Dockerfile.reactjs ./Dockerfile
cp /path/to/vps-deployment-kit/docker/compose/docker-compose.reactjs.yml ./docker-compose.yml

cp .env.example .env
nano .env

# Build with environment variables baked in
docker compose build --build-arg VITE_API_URL=https://api.yourdomain.com
docker compose up -d
```

> **📁 Files:** [`Dockerfile.reactjs`](dockerfiles/Dockerfile.reactjs) · [`docker-compose.reactjs.yml`](compose/docker-compose.reactjs.yml)

### NestJS

```bash
cd /var/www/apps/yourapp

cp /path/to/vps-deployment-kit/docker/dockerfiles/Dockerfile.nestjs ./Dockerfile
cp /path/to/vps-deployment-kit/docker/compose/docker-compose.nestjs.yml ./docker-compose.yml
mkdir -p docker/nginx
cp /path/to/vps-deployment-kit/docker/nginx/nginx-docker-node.conf ./docker/nginx/default.conf

cp .env.example .env
nano .env

docker compose up -d

# If using Prisma ORM
docker compose exec app npx prisma migrate deploy
```

> **📁 Files:** [`Dockerfile.nestjs`](dockerfiles/Dockerfile.nestjs) · [`docker-compose.nestjs.yml`](compose/docker-compose.nestjs.yml) · [`nginx-docker-node.conf`](nginx/nginx-docker-node.conf)

---

## 4. Docker Concepts Explained

### Images vs Containers

```
Dockerfile  ──build──▶  Image  ──run──▶  Container
(recipe)                (snapshot)        (running process)
```

- **Image:** A read-only template. Think of it as a class. Built from a Dockerfile.
- **Container:** A running instance of an image. Think of it as an object. You can have multiple containers from one image.

```bash
docker build -t myapp .        # Dockerfile → Image
docker run -d myapp            # Image → Container
docker images                  # List all images
docker ps                      # List running containers
```

### Docker Compose Services

Docker Compose lets you define multi-container applications in a single YAML file. Each **service** becomes a container:

```yaml
services:
  app:      # → myapp-laravel container (your code)
  nginx:    # → myapp-nginx container (web server)
  mysql:    # → myapp-mysql container (database)
  redis:    # → myapp-redis container (cache)
```

All our compose files follow this pattern. See [`docker-compose.laravel.yml`](compose/docker-compose.laravel.yml) for a complete example.

### Volumes — Persisting Data

Containers are **ephemeral** — when removed, all data inside is lost. Volumes persist data outside the container lifecycle.

```yaml
volumes:
  mysql-data:          # Named volume — Docker manages the storage location
    driver: local

services:
  mysql:
    volumes:
      - mysql-data:/var/lib/mysql    # Named volume → survives container removal
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql  # Bind mount → file from host
```

> **🚨 CRITICAL:** Without a volume on your database data directory, you **will lose all data** when the container is removed or rebuilt. Every compose file in this kit includes proper volume definitions.

### Networks — How Containers Talk

Containers on the same Docker network can reach each other **by service name**:

```yaml
services:
  app:
    environment:
      DB_HOST: mysql       # ← the service name IS the hostname
      REDIS_HOST: redis    # ← same here
  mysql:
    # ...
  redis:
    # ...

networks:
  app-network:
    driver: bridge         # All services share this network
```

- `app` can reach `mysql` at `mysql:3306`
- `app` can reach `redis` at `redis:6379`
- `nginx` can reach `app` at `app:9000` (PHP-FPM) or `app:3000` (Node.js)
- External traffic cannot reach containers directly unless ports are published

### Build Stages (Multi-Stage Builds)

Multi-stage builds produce smaller images by discarding build tools in the final stage:

```dockerfile
# Stage 1: Install ALL dependencies + build
FROM node:20-alpine AS builder
COPY . .
RUN npm ci && npm run build       # ~800 MB with devDependencies

# Stage 2: Production — only runtime dependencies + compiled output
FROM node:20-alpine AS production
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules  # prod only
# Final image: ~150 MB
```

All Dockerfiles in this kit use multi-stage builds. See [`Dockerfile.laravel`](dockerfiles/Dockerfile.laravel) for a 3-stage build (Composer → Frontend → Production).

### .dockerignore

Like `.gitignore` but for Docker builds. Without it, Docker copies everything (including `node_modules`, `.git`, etc.) into the build context, making builds slow and images bloated.

```
# ALWAYS create a .dockerignore in your project root
node_modules
.git
.env
*.md
```

See [Section 13](#13-dockerignore-templates) for complete templates.

---

## 5. Dockerfile Best Practices

### Multi-Stage Builds

Every Dockerfile in this kit uses multi-stage builds. The pattern:

```dockerfile
# Stage 1: Build (has compilers, dev dependencies)
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production (minimal, no dev tools)
FROM node:20-alpine AS production
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
CMD ["node", "dist/index.js"]
```

**Result:** Final image contains only what's needed to run (no TypeScript compiler, no build tools, no source maps).

### Layer Caching — Copy Package Files First

Docker caches layers. If a layer hasn't changed, it's reused. This is why we **always copy dependency files before application code**:

```dockerfile
# ✅ GOOD — dependencies are cached unless package.json changes
COPY package.json package-lock.json* ./
RUN npm ci                              # Cached if package.json unchanged
COPY . .                                # Only this layer rebuilds on code changes
RUN npm run build

# ❌ BAD — every code change re-installs all dependencies
COPY . .
RUN npm ci && npm run build
```

This optimization is used in every Dockerfile in this kit. Rebuilds go from minutes to seconds.

### Non-Root User

Never run containers as root in production. Our Node.js Dockerfiles create a dedicated user:

```dockerfile
# From Dockerfile.nodejs
RUN addgroup -g 1001 -S appgroup \
    && adduser -S appuser -u 1001 -G appgroup

# ... copy files ...

RUN chown -R appuser:appgroup /app
USER appuser
```

PHP-FPM images use the built-in `www-data` user with proper permissions:

```dockerfile
# From Dockerfile.php / Dockerfile.laravel
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 775 storage bootstrap/cache
```

### HEALTHCHECK Directive

Health checks let Docker (and Compose) know when your app is actually ready:

```dockerfile
# Node.js / NestJS / Next.js
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:3000/health || exit 1

# React (Nginx)
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost/ || exit 1
```

This powers `depends_on` with `condition: service_healthy` in Compose — so Nginx waits for your app to be ready before accepting traffic.

### .dockerignore Examples

See [Section 13](#13-dockerignore-templates) for complete, copy-paste-ready `.dockerignore` files for every project type.

---

## 6. Docker Compose Deep Dive

### Service Dependencies

Use `depends_on` with health check conditions to control startup order:

```yaml
services:
  app:
    depends_on:
      mysql:
        condition: service_healthy    # Wait for MySQL to accept connections
      redis:
        condition: service_healthy    # Wait for Redis to respond to PING

  nginx:
    depends_on:
      app:
        condition: service_healthy    # Wait for app to respond

  mysql:
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
```

> **⚠️ Without health checks**, `depends_on` only waits for the container to *start*, not for the service inside to be *ready*. This is the #1 cause of "database connection refused" errors.

### Environment Variables

Two approaches — use whichever fits your workflow:

**Option 1: `env_file`** — Load from a file (recommended for many variables):

```yaml
services:
  app:
    env_file:
      - .env                          # All vars from .env are injected
```

**Option 2: `environment`** — Set directly in compose (good for service-specific overrides):

```yaml
services:
  app:
    environment:
      DB_HOST: mysql                  # Override .env values
      REDIS_HOST: redis
      NODE_ENV: production
```

**Option 3: Both** — `env_file` loads defaults, `environment` overrides specific values:

```yaml
services:
  app:
    env_file:
      - .env
    environment:
      DB_HOST: mysql                  # Overrides DB_HOST from .env
```

> **💡 Tip:** Never commit `.env` files. Use `.env.example` as a template.

### Volume Mounts

**Named volumes** — Docker manages storage. Best for databases:

```yaml
volumes:
  mysql-data:
    driver: local

services:
  mysql:
    volumes:
      - mysql-data:/var/lib/mysql     # Persists between container restarts
```

**Bind mounts** — Map a host directory into the container:

```yaml
services:
  nginx:
    volumes:
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro  # :ro = read-only
      - .:/var/www/html               # Full app code (development)
```

| Type | Use Case | Survives `docker compose down`? |
|---|---|---|
| Named volume | Database data, Redis data | ✅ Yes (unless `-v` flag) |
| Bind mount | Config files, dev code | ✅ Yes (it's on your host) |
| Anonymous volume | Temp data | ❌ No |

> **🚨 Warning:** `docker compose down -v` removes named volumes. **Never** use `-v` unless you want to delete your database.

### Restart Policies

```yaml
services:
  app:
    restart: unless-stopped           # Restart always, except when manually stopped
```

| Policy | Behavior |
|---|---|
| `no` | Never restart (default) |
| `always` | Always restart, even after manual stop |
| `unless-stopped` | Restart unless you ran `docker compose stop` |
| `on-failure` | Restart only on non-zero exit code |

All compose files in this kit use `restart: unless-stopped` for production resilience.

### Resource Limits

<a name="resource-limits"></a>

Critical for VPS with limited RAM:

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'
        reservations:
          memory: 256M
          cpus: '0.5'

  mysql:
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

  redis:
    deploy:
      resources:
        limits:
          memory: 128M
```

**Recommended limits by VPS size:**

| VPS RAM | App | MySQL/Postgres | Redis | Nginx |
|---|---|---|---|---|
| 1 GB | 256M | 384M | 64M | 64M |
| 2 GB | 512M | 768M | 128M | 128M |
| 4 GB | 1G | 1.5G | 256M | 128M |

### Profiles — Dev vs Production

Separate development-only services using profiles:

```yaml
services:
  app:
    # ... always runs

  mysql:
    # ... always runs

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    profiles: ["dev"]                 # Only starts with --profile dev
    ports:
      - "8080:80"
    environment:
      PMA_HOST: mysql

  mailpit:
    image: axllent/mailpit
    profiles: ["dev"]
    ports:
      - "8025:8025"
      - "1025:1025"
```

```bash
# Production — phpmyadmin and mailpit won't start
docker compose up -d

# Development — includes dev tools
docker compose --profile dev up -d
```

---

## 7. Networking — Docker + Nginx + SSL

### Option A: Nginx Inside Docker (Container-to-Container)

This is what our compose files use. Nginx runs as a container alongside your app:

```
Internet → :80/:443 → [Nginx Container] → [App Container :9000/:3000]
                                         → [MySQL Container :3306]
```

**How it works:** The Nginx container and app container share a Docker network. Nginx reaches the app by service name:

- PHP/Laravel: `fastcgi_pass app:9000;` (see [`nginx-docker-php.conf`](nginx/nginx-docker-php.conf))
- Node.js/Next.js/NestJS: `proxy_pass http://app:3000;` (see [`nginx-docker-node.conf`](nginx/nginx-docker-node.conf))

**Best for:** Single-app deployments, simple setups, when everything is in Docker.

### Option B: Nginx on Host, Proxy to Docker Containers

Nginx runs directly on the host OS and proxies to Docker containers via published ports:

```
Internet → :80/:443 → [Host Nginx] → localhost:8001 → [App1 Container]
                                    → localhost:8002 → [App2 Container]
                                    → localhost:8003 → [App3 Container]
```

**Setup:** Publish container ports on localhost, then configure host Nginx:

```yaml
# docker-compose.yml — don't expose port 80, use a high port
services:
  app:
    ports:
      - "127.0.0.1:8001:3000"       # Only accessible from localhost
```

```nginx
# /etc/nginx/sites-available/myapp.conf (host Nginx)
server {
    listen 80;
    server_name myapp.com;

    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Best for:** Multiple apps on one VPS, when you already have Nginx on the host, or when you want Certbot to manage SSL directly on the host.

### SSL Approach 1: Certbot on Host + Mount Certs into Container

The simplest approach — use Certbot on the host and share certificates with Docker:

```bash
# On host: install Certbot and get certificate
sudo apt install certbot
sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com
```

Then mount the certs into your Nginx container:

```yaml
# docker-compose.yml
services:
  nginx:
    volumes:
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro          # Mount certs
      - /var/www/certbot:/var/www/certbot:ro           # ACME challenge
    ports:
      - "80:80"
      - "443:443"
```

Update your Nginx config to use SSL:

```nginx
# docker/nginx/default.conf
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # For PHP/Laravel:
    location ~ \.php$ {
        fastcgi_pass app:9000;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # For Node.js/Next.js/NestJS:
    # location / {
    #     proxy_pass http://app:3000;
    #     proxy_set_header Host $host;
    #     proxy_set_header X-Forwarded-Proto $scheme;
    # }
}
```

Set up auto-renewal with a cron job on the host:

```bash
# Add to crontab: sudo crontab -e
0 3 * * * certbot renew --quiet && docker compose -f /var/www/apps/yourapp/docker-compose.yml exec nginx nginx -s reload
```

### SSL Approach 2: Automatic SSL with nginx-proxy + acme-companion

Fully automated — containers get SSL certificates automatically:

```yaml
# docker-compose.ssl-proxy.yml — Run this ONCE on your VPS
services:
  nginx-proxy:
    image: nginxproxy/nginx-proxy
    container_name: nginx-proxy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - certs:/etc/nginx/certs:ro
      - vhost:/etc/nginx/vhost.d
      - html:/usr/share/nginx/html
    networks:
      - proxy-network

  acme-companion:
    image: nginxproxy/acme-companion
    container_name: acme-companion
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - certs:/etc/nginx/certs
      - vhost:/etc/nginx/vhost.d
      - html:/usr/share/nginx/html
      - acme:/etc/acme.sh
    environment:
      DEFAULT_EMAIL: you@example.com
    depends_on:
      - nginx-proxy
    networks:
      - proxy-network

volumes:
  certs:
  vhost:
  html:
  acme:

networks:
  proxy-network:
    name: proxy-network
    driver: bridge
```

Then in each app's compose file, add environment variables instead of port mappings:

```yaml
# docker-compose.yml for your app
services:
  app:
    build: .
    environment:
      VIRTUAL_HOST: myapp.com,www.myapp.com
      VIRTUAL_PORT: 3000
      LETSENCRYPT_HOST: myapp.com,www.myapp.com
      LETSENCRYPT_EMAIL: you@example.com
    networks:
      - proxy-network
    # NO ports needed — nginx-proxy handles routing

networks:
  proxy-network:
    external: true
    name: proxy-network
```

```bash
# Start the proxy (once)
docker compose -f docker-compose.ssl-proxy.yml up -d

# Deploy your app (no ports, no SSL config needed)
cd /var/www/apps/yourapp
docker compose up -d
# SSL certificate is automatically obtained and renewed!
```

**When to use which:**

| Approach | Pros | Cons |
|---|---|---|
| Certbot on host | Simple, full control | Manual renewal cron, manual Nginx config |
| nginx-proxy + acme | Fully automatic, zero config per app | Extra containers running, Docker socket access |
| Host Nginx + Certbot | Works with non-Docker apps too | Not containerized, mixed approach |

---

## 8. Database Management with Docker

### Persisting Data with Volumes

> **🚨 This is the most important section in this guide.** Without volumes, your database data lives inside the container and is **permanently lost** when the container is removed.

Every compose file in this kit includes proper volume definitions:

```yaml
volumes:
  mysql-data:
    driver: local

services:
  mysql:
    volumes:
      - mysql-data:/var/lib/mysql           # ← This is what saves your data
```

```bash
# Verify your volumes exist
docker volume ls

# Inspect a volume (see where data is stored on host)
docker volume inspect yourapp_mysql-data
```

### Backup — MySQL

```bash
# Backup to a SQL file
docker compose exec mysql mysqldump -u root -prootsecret myapp_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup all databases
docker compose exec mysql mysqldump -u root -prootsecret --all-databases > full_backup_$(date +%Y%m%d_%H%M%S).sql

# Compressed backup
docker compose exec mysql mysqldump -u root -prootsecret myapp_db | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Backup — PostgreSQL

```bash
# Backup to a SQL file
docker compose exec postgres pg_dump -U myapp_user myapp_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Custom format (smaller, supports parallel restore)
docker compose exec postgres pg_dump -U myapp_user -Fc myapp_db > backup_$(date +%Y%m%d_%H%M%S).dump

# Compressed backup
docker compose exec postgres pg_dump -U myapp_user myapp_db | gzip > backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

### Restore from Backup

```bash
# MySQL
docker compose exec -T mysql mysql -u root -prootsecret myapp_db < backup.sql

# PostgreSQL
docker compose exec -T postgres psql -U myapp_user myapp_db < backup.sql

# PostgreSQL custom format
docker compose exec -T postgres pg_restore -U myapp_user -d myapp_db backup.dump
```

### Automated Backup Script

```bash
#!/bin/bash
# save as: backup-db.sh
APP_DIR="/var/www/apps/yourapp"
BACKUP_DIR="$APP_DIR/backups"
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"
cd "$APP_DIR"

# MySQL backup
docker compose exec -T mysql mysqldump -u root -prootsecret myapp_db | gzip > "$BACKUP_DIR/db_$(date +%Y%m%d_%H%M%S).sql.gz"

# Delete backups older than $RETENTION_DAYS days
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup complete. Files in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"
```

```bash
# Run daily at 2 AM — add to crontab
0 2 * * * /var/www/apps/yourapp/backup-db.sh >> /var/log/db-backup.log 2>&1
```

### Accessing Database from Host

Port mappings let you connect from the host or external tools (TablePlus, DBeaver, etc.):

```yaml
services:
  mysql:
    ports:
      - "127.0.0.1:3307:3306"        # Host port 3307 → Container port 3306
      # 127.0.0.1 = only accessible from localhost (secure)
```

```bash
# Connect from host
mysql -h 127.0.0.1 -P 3307 -u myapp_user -p myapp_db

# PostgreSQL
psql -h 127.0.0.1 -p 5433 -U myapp_user myapp_db
```

> **💡 Security:** Always bind to `127.0.0.1` (not `0.0.0.0`) to prevent external access to your database port.

### Database Migrations in Docker

```bash
# Laravel
docker compose exec app php artisan migrate
docker compose exec app php artisan migrate --force        # Production (no confirmation)

# Prisma (NestJS / Next.js)
docker compose exec app npx prisma migrate deploy          # Production
docker compose exec app npx prisma migrate dev             # Development

# TypeORM
docker compose exec app npm run typeorm migration:run

# Knex.js
docker compose exec app npx knex migrate:latest
```

---

## 9. Common Docker Commands

### Build & Run

```bash
docker compose up -d                            # Start all services (detached)
docker compose up -d --build                    # Rebuild images then start
docker compose build                            # Build without starting
docker compose build --no-cache                 # Build from scratch (ignore cache)
docker compose build app                        # Build only the app service
```

### Stop & Remove

```bash
docker compose stop                             # Stop containers (keep them)
docker compose down                             # Stop and remove containers + networks
docker compose down -v                          # ⚠️ Also remove volumes (DATA LOSS!)
docker compose down --rmi all                   # Also remove built images
```

### Logs

```bash
docker compose logs                             # All services
docker compose logs app                         # Single service
docker compose logs -f app                      # Follow (tail) logs
docker compose logs --tail=100 app              # Last 100 lines
docker compose logs --since=1h                  # Logs from last hour
docker compose logs -f app nginx                # Multiple services
```

### Execute Commands

```bash
docker compose exec app bash                    # Interactive shell
docker compose exec app sh                      # Alpine (no bash)
docker compose exec app php artisan tinker      # Laravel Tinker
docker compose exec app node                    # Node.js REPL
docker compose exec mysql mysql -u root -p      # MySQL client
docker compose exec -T app php artisan migrate  # Non-interactive (-T)
```

### Status & Inspection

```bash
docker compose ps                               # Container status
docker compose ps -a                            # Include stopped containers
docker compose top                              # Running processes
docker stats                                    # Live resource usage
docker compose images                           # Images used by services
```

### Restart & Rebuild

```bash
docker compose restart                          # Restart all services
docker compose restart app                      # Restart single service
docker compose up -d --force-recreate app       # Recreate container
docker compose up -d --build app                # Rebuild + restart single service
```

### Cleanup

```bash
docker system prune                             # Remove unused data
docker system prune -a                          # Remove ALL unused images
docker system prune --volumes                   # ⚠️ Also remove unused volumes
docker image prune                              # Remove dangling images
docker volume prune                             # ⚠️ Remove unused volumes
docker builder prune                            # Clear build cache
docker system df                                # Show disk usage
```

### Quick Reference Table

| Task | Command |
|---|---|
| Start everything | `docker compose up -d` |
| Rebuild and start | `docker compose up -d --build` |
| Stop everything | `docker compose down` |
| View logs | `docker compose logs -f` |
| Shell into container | `docker compose exec app sh` |
| Run migrations | `docker compose exec app php artisan migrate` |
| Check status | `docker compose ps` |
| Resource usage | `docker stats` |
| Free disk space | `docker system prune -a` |

---

## 10. Docker Deployment Workflow

### Manual Deployment

```bash
ssh deploy@your-vps-ip
cd /var/www/apps/yourapp

# Pull latest code
git pull origin main

# Rebuild and restart
docker compose build --no-cache
docker compose up -d --force-recreate --remove-orphans

# Run migrations (pick one)
docker compose exec -T app php artisan migrate --force      # Laravel
docker compose exec -T app npx prisma migrate deploy        # Prisma

# Clean up old images
docker image prune -f

# Verify
docker compose ps
curl -s http://localhost/ | head -5
```

### GitHub Actions CI/CD

This kit includes a ready-to-use workflow at [`workflows/deploy-docker.yml`](../workflows/deploy-docker.yml).

**Setup:**

1. Copy the workflow to your project:
   ```bash
   mkdir -p .github/workflows
   cp /path/to/vps-deployment-kit/workflows/deploy-docker.yml .github/workflows/deploy.yml
   ```

2. Add GitHub Secrets (Settings → Secrets → Actions):
   - `VPS_HOST` — Your VPS IP address
   - `VPS_USERNAME` — Deploy user (e.g., `deploy`)
   - `VPS_SSH_KEY` — Private SSH key

3. Push to `main` — deployment runs automatically.

**What it does:**
1. Builds the Docker image (validates the Dockerfile works)
2. SSHes into your VPS
3. Pulls latest code with `git pull`
4. Runs `docker compose build --no-cache`
5. Runs `docker compose up -d --force-recreate`
6. Runs health checks

### Zero-Downtime Deployment

For zero-downtime updates, use the blue-green approach with Docker Compose:

```bash
#!/bin/bash
# zero-downtime-deploy.sh
APP_DIR="/var/www/apps/yourapp"
cd "$APP_DIR"

# Pull latest code
git pull origin main

# Build new image without stopping current containers
docker compose build

# Scale up new containers alongside old ones
docker compose up -d --no-deps --scale app=2 --no-recreate app

# Wait for new container to be healthy
sleep 15

# Remove old container (Compose keeps the new one)
docker compose up -d --no-deps --force-recreate app

# Verify
docker compose ps
curl -sf http://localhost/ > /dev/null && echo "✅ Healthy" || echo "❌ Failed"
```

### Rollback Strategy

```bash
# Option 1: Git-based rollback
cd /var/www/apps/yourapp
git log --oneline -5                            # Find the last good commit
git checkout <commit-hash>
docker compose up -d --build

# Option 2: Keep previous images tagged
docker compose build                            # Builds new image
docker tag yourapp:latest yourapp:rollback      # Tag current as rollback

# If deploy fails:
docker tag yourapp:rollback yourapp:latest
docker compose up -d --force-recreate

# Option 3: Docker image history
docker images yourapp --format "table {{.ID}}\t{{.CreatedAt}}\t{{.Size}}"
docker tag <old-image-id> yourapp:latest
docker compose up -d --force-recreate
```

---

## 11. Monitoring Docker Containers

### Resource Usage

```bash
# Live stats (CPU, memory, network, I/O)
docker stats

# Formatted output
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# One-shot (non-streaming)
docker stats --no-stream
```

### Logs

```bash
# Follow all logs
docker compose logs -f

# Follow specific service with timestamps
docker compose logs -f --timestamps app

# Recent logs only
docker compose logs --tail=200 --since=30m app
```

### Container Health Checks

```bash
# Check health status
docker inspect --format='{{.State.Health.Status}}' myapp-node

# View health check log
docker inspect --format='{{json .State.Health}}' myapp-node | python3 -m json.tool

# List all containers with health status
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Auto-Restart Unhealthy Containers

Docker's `restart: unless-stopped` policy handles crash restarts, but doesn't restart containers that are "unhealthy." Use this simple watchdog script:

```bash
#!/bin/bash
# docker-watchdog.sh — restarts unhealthy containers
COMPOSE_DIR="/var/www/apps/yourapp"

cd "$COMPOSE_DIR"

unhealthy=$(docker ps --filter "health=unhealthy" --format "{{.Names}}")

if [ -n "$unhealthy" ]; then
    echo "$(date): Unhealthy containers found: $unhealthy"
    for container in $unhealthy; do
        echo "Restarting $container..."
        docker restart "$container"
    done
fi
```

```bash
# Run every 2 minutes
*/2 * * * * /var/www/apps/yourapp/docker-watchdog.sh >> /var/log/docker-watchdog.log 2>&1
```

---

## 12. Troubleshooting

### Container Won't Start

```bash
# Check exit code and error
docker compose ps -a
docker compose logs app

# Common causes:
# - Missing .env file → cp .env.example .env
# - Port conflict → change APP_PORT in .env
# - Bad Dockerfile CMD → test with: docker compose run --rm app sh
```

### Port Already in Use

```bash
# Find what's using the port
sudo lsof -i :80
sudo ss -tlnp | grep :80

# Solutions:
# 1. Stop the conflicting process
# 2. Change the port in docker-compose.yml:
#    ports:
#      - "8080:80"    # Use 8080 instead
# 3. Stop host Nginx if using Docker Nginx:
#    sudo systemctl stop nginx
```

### Database Connection Refused

This almost always means the app started before the database was ready.

```bash
# Check if database is healthy
docker compose ps mysql

# Fix: Add health check + condition (already in our compose files)
# services:
#   app:
#     depends_on:
#       mysql:
#         condition: service_healthy
#   mysql:
#     healthcheck:
#       test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]

# Temporary fix: restart the app after database is ready
docker compose restart app
```

### Out of Disk Space

```bash
# Check Docker disk usage
docker system df

# Nuclear option — remove everything unused
docker system prune -a
docker builder prune -a

# Less aggressive — only dangling images and stopped containers
docker container prune
docker image prune
```

### Permission Issues with Volumes

```bash
# Check file ownership inside container
docker compose exec app ls -la /var/www/html

# Fix PHP/Laravel permissions
docker compose exec app chown -R www-data:www-data /var/www/html/storage
docker compose exec app chmod -R 775 /var/www/html/storage

# Fix Node.js permissions (if volume-mounted)
docker compose exec app chown -R appuser:appgroup /app

# Common cause: host UID ≠ container UID
# Solution: match UIDs in Dockerfile
# RUN adduser -S appuser -u 1000    # Match host user's UID
```

### Build Cache Issues

```bash
# Rebuild ignoring all cache
docker compose build --no-cache

# Clear the build cache
docker builder prune -a

# Force pull base images
docker compose build --pull --no-cache
```

### Container Keeps Restarting

```bash
# Check restart count and logs
docker inspect --format='{{.RestartCount}}' myapp-node
docker compose logs --tail=50 app

# Common causes:
# - App crashes on startup (check logs)
# - OOM killed (check docker stats, increase memory limit)
# - Bad CMD/ENTRYPOINT in Dockerfile
# - Missing environment variables

# Check if OOM killed
docker inspect --format='{{.State.OOMKilled}}' myapp-node
```

---

## 13. .dockerignore Templates

> **Always create a `.dockerignore` in your project root.** Without it, Docker sends everything (including `node_modules`, `.git`, test files) to the build daemon — making builds slow and images bloated.

### Node.js / Next.js / NestJS / React

```dockerignore
# Dependencies (rebuilt inside container)
node_modules
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Build output (rebuilt inside container)
dist
build
.next
out

# Git
.git
.gitignore

# Environment (secrets — never bake into images)
.env
.env.*
!.env.example

# IDE
.vscode
.idea
*.swp
*.swo

# Testing
coverage
.nyc_output
__tests__
*.test.js
*.test.ts
*.spec.js
*.spec.ts

# Docker (avoid recursive copy)
Dockerfile*
docker-compose*
.dockerignore

# Documentation
*.md
LICENSE
docs

# OS files
.DS_Store
Thumbs.db

# CI/CD
.github
.gitlab-ci.yml
```

### PHP / Laravel

```dockerignore
# Dependencies (rebuilt inside container)
vendor

# Git
.git
.gitignore
.gitattributes

# Environment
.env
.env.*
!.env.example

# Node (if frontend is built in multi-stage)
node_modules
npm-debug.log*

# IDE
.vscode
.idea
.phpstorm.meta.php
_ide_helper*.php
*.swp

# Testing
tests
phpunit.xml
.phpunit.result.cache
coverage

# Laravel development files
storage/logs/*
storage/framework/cache/data/*
storage/framework/sessions/*
storage/framework/views/*

# Docker
Dockerfile*
docker-compose*
.dockerignore

# Documentation
*.md
LICENSE
docs

# CI/CD
.github
.gitlab-ci.yml

# OS files
.DS_Store
Thumbs.db
```

---

## 14. Docker vs PM2 — When to Use What

| Criteria | Docker | PM2 |
|---|---|---|
| **Setup complexity** | Medium (Dockerfile + Compose) | Low (just `pm2 start app.js`) |
| **Resource overhead** | Higher (~50–100 MB per container) | Lower (~10–20 MB per process) |
| **Isolation** | Full (filesystem, network, PID) | Process-level only |
| **Reproducibility** | Excellent (same image everywhere) | Depends on server setup |
| **Multi-language** | Any language in any container | Node.js only |
| **Database included** | Yes (MySQL, Postgres, Redis in Compose) | No (install separately) |
| **Scaling** | `docker compose up --scale app=3` | `pm2 scale app 3` |
| **Zero-downtime restart** | Needs orchestration | Built-in (`pm2 reload`) |
| **Log management** | `docker compose logs -f` | `pm2 logs` + log rotation |
| **Server monitoring** | `docker stats` (basic) | `pm2 monit` (built-in) |
| **Learning curve** | Steeper | Gentle |
| **Team development** | Better (consistent environments) | Fine for solo/small teams |
| **CI/CD integration** | Native (build → push → deploy image) | SSH + git pull + pm2 reload |

### Use PM2 When:

- Running a **single Node.js app** on a VPS
- Your VPS has **limited RAM** (1 GB) and you need minimal overhead
- You want the **simplest possible setup** — no Dockerfiles to maintain
- You're a **solo developer** and "works on my machine" isn't a concern
- Your app doesn't need a database container (using external DB or SQLite)

> **📁 See:** [`pm2/`](../pm2/) directory for PM2 ecosystem configs.

### Use Docker When:

- Running **multiple apps** on one VPS (isolation prevents conflicts)
- Working on a **team** (Dockerfile = consistent environment for everyone)
- Your app needs **MySQL, PostgreSQL, Redis** alongside it
- You need to deploy **non-Node.js apps** (PHP, Laravel, Python, Go)
- You want **reproducible deployments** (same image in staging and production)
- You plan to **scale** to multiple servers or Kubernetes later

> **📁 See:** All files in this `docker/` directory.

### Can You Use Both?

Yes! A common pattern:

- **Docker** for databases (MySQL, PostgreSQL, Redis) — easy setup, volume persistence
- **PM2** for your Node.js app — lower overhead, simpler restarts

```bash
# Run database in Docker
docker compose up -d mysql redis

# Run app with PM2
pm2 start ecosystem.config.js
```

---

## Quick Links

| Resource | Path |
|---|---|
| **Dockerfiles** | [`docker/dockerfiles/`](dockerfiles/) |
| **Compose files** | [`docker/compose/`](compose/) |
| **Nginx configs** | [`docker/nginx/`](nginx/) |
| **Deploy workflow** | [`workflows/deploy-docker.yml`](../workflows/deploy-docker.yml) |
| **PM2 configs** | [`pm2/`](../pm2/) |
| **VPS setup script** | [`vps-setup.sh`](../vps-setup.sh) |
| **Full deployment guide** | [`DEPLOYMENT-GUIDE.md`](../DEPLOYMENT-GUIDE.md) |
| **Cheatsheet** | [`CHEATSHEET.md`](../CHEATSHEET.md) |
