# 🔒 Firewall & Security Hardening Guide

> **Target OS:** Ubuntu 22.04 LTS VPS  
> **Last Updated:** 2025  
> **Part of:** [VPS Deployment Kit](../README.md)

This guide covers firewall configuration, intrusion prevention, SSH hardening, Nginx security, and system-level best practices for production VPS servers.

### What `vps-setup.sh` Already Handles

The automated setup script configures a baseline. This guide explains how to **customize, extend, and audit** that baseline.

| Feature | Handled by `vps-setup.sh` | Needs Manual Setup |
|---|---|---|
| UFW install & enable | ✅ Deny incoming, allow outgoing, SSH, Nginx Full | Custom ports, IP allowlists, rate limiting |
| Fail2Ban | ✅ Installed, SSH jail (5 retries / 1hr ban) | Nginx jails, custom jails, tuning |
| SSH hardening | ✅ Key-only auth, root password login disabled | Port change, AllowUsers, 2FA, idle timeout |
| Nginx security | ❌ | Security headers, version hiding, rate limiting |
| Auto security updates | ✅ `unattended-upgrades` | Audit & verify configuration |
| Deploy user | ✅ Creates `deploy` user with sudo | File permissions audit |

---

## Table of Contents

1. [UFW (Uncomplicated Firewall)](#1-ufw-uncomplicated-firewall)
2. [Fail2Ban](#2-fail2ban)
3. [SSH Hardening](#3-ssh-hardening)
4. [Nginx Security](#4-nginx-security)
5. [System Security](#5-system-security)
6. [Security Checklist](#6-security-checklist)

---

## 1. UFW (Uncomplicated Firewall)

> **Note:** `vps-setup.sh` installs UFW, sets default deny/allow policies, and opens SSH + Nginx Full (80/443). The commands below let you customize further.

### 1.1 Install and Enable

```bash
# Install UFW (already done by vps-setup.sh)
sudo apt update && sudo apt install -y ufw

# ⚠️  IMPORTANT: Always allow SSH BEFORE enabling UFW or you will lock yourself out
sudo ufw allow ssh

# Enable the firewall
sudo ufw --force enable

# Verify it's active
sudo ufw status verbose
```

### 1.2 Default Policies

```bash
# Deny all incoming traffic by default
sudo ufw default deny incoming

# Allow all outgoing traffic by default
sudo ufw default allow outgoing

# (Optional) Deny forwarding — recommended unless running Docker/containers
sudo ufw default deny routed
```

### 1.3 Allow SSH, HTTP, HTTPS

```bash
# Allow SSH (port 22)
sudo ufw allow ssh

# Allow HTTP and HTTPS individually
sudo ufw allow http
sudo ufw allow https

# Or allow both at once using the Nginx profile (already done by vps-setup.sh)
sudo ufw allow 'Nginx Full'
```

### 1.4 Allow Specific Ports

```bash
# Node.js app (development/direct access)
sudo ufw allow 3000/tcp

# PostgreSQL — only allow if external access is truly needed
sudo ufw allow 5432/tcp

# MySQL
sudo ufw allow 3306/tcp

# Redis
sudo ufw allow 6379/tcp

# Custom port range (e.g., for media streaming)
sudo ufw allow 8000:8100/tcp

# Allow a port for both TCP and UDP
sudo ufw allow 53
```

> **⚠️ Security Tip:** For databases (PostgreSQL, MySQL, Redis), prefer restricting to specific IPs instead of opening the port to the world. See the next section.

### 1.5 Allow from Specific IPs Only

```bash
# Allow SSH only from your office IP
sudo ufw allow from 203.0.113.50 to any port 22

# Allow PostgreSQL only from your app server
sudo ufw allow from 10.0.0.5 to any port 5432

# Allow an entire subnet (e.g., private network)
sudo ufw allow from 10.0.0.0/24

# Allow a subnet to a specific port
sudo ufw allow from 192.168.1.0/24 to any port 3306

# Deny a specific IP address
sudo ufw deny from 198.51.100.0

# Deny a specific IP on a specific port
sudo ufw deny from 198.51.100.0 to any port 443
```

### 1.6 Rate Limiting with UFW

UFW has a built-in rate limiter that denies connections from an IP that attempts 6+ connections within 30 seconds.

```bash
# Rate limit SSH to prevent brute-force attacks
sudo ufw limit ssh

# Rate limit a custom SSH port
sudo ufw limit 2222/tcp

# Rate limit with specific comment for documentation
sudo ufw limit ssh comment 'Rate limit SSH connections'
```

> **Note:** UFW's `limit` is basic (6 connections / 30 seconds). For more granular rate limiting, use Fail2Ban or Nginx rate limiting (covered later).

### 1.7 Delete Rules

```bash
# List rules with numbers
sudo ufw status numbered

# Delete a rule by its number
sudo ufw delete 3

# Delete a rule by its specification
sudo ufw delete allow 3000/tcp

# Delete a specific allow rule
sudo ufw delete allow from 203.0.113.50 to any port 22

# Reset UFW completely (removes ALL rules — be careful)
sudo ufw --force reset
```

### 1.8 UFW Status and Management

```bash
# Detailed status with rule numbers
sudo ufw status numbered

# Verbose status (shows defaults + logging)
sudo ufw status verbose

# Enable logging (useful for debugging)
sudo ufw logging on

# Set logging level (off, low, medium, high, full)
sudo ufw logging medium

# View UFW logs
sudo tail -f /var/log/ufw.log

# Disable UFW temporarily (for debugging only!)
sudo ufw disable

# Re-enable UFW
sudo ufw enable

# Reload rules without disabling
sudo ufw reload
```

### 1.9 Common UFW Application Profiles

```bash
# List all available application profiles
sudo ufw app list

# Get details about a specific profile
sudo ufw app info 'Nginx Full'
sudo ufw app info 'OpenSSH'

# Common profiles:
# - OpenSSH        → port 22/tcp
# - Nginx HTTP     → port 80/tcp
# - Nginx HTTPS    → port 443/tcp
# - Nginx Full     → ports 80,443/tcp
```

<details>
<summary>📋 Example: Production UFW configuration</summary>

```bash
#!/bin/bash
# Production firewall setup — run as root

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# Core services
ufw allow ssh
ufw allow 'Nginx Full'

# Rate limit SSH
ufw limit ssh

# Allow database access from app server only
ufw allow from 10.0.0.5 to any port 5432  # PostgreSQL from app server

# Enable
ufw --force enable
ufw status verbose
```

</details>

---

## 2. Fail2Ban

> **Note:** `vps-setup.sh` installs Fail2Ban and creates a basic SSH jail (`maxretry=5`, `bantime=3600`, `findtime=600`). The commands below let you extend that configuration.

### 2.1 Install and Configure

```bash
# Install Fail2Ban (already done by vps-setup.sh)
sudo apt install -y fail2ban

# Enable and start the service
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Never edit jail.conf directly — always use jail.local for overrides
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

**Global defaults** — edit `/etc/fail2ban/jail.local`:

```bash
sudo nano /etc/fail2ban/jail.local
```

```ini
[DEFAULT]
# Ban duration (seconds). 3600 = 1 hour, -1 = permanent
bantime  = 3600

# Time window to count failures (seconds)
findtime = 600

# Max failures before ban
maxretry = 5

# Action: ban the IP using UFW (see section 2.7)
banaction = ufw

# Email notification (optional — requires sendmail/postfix)
# destemail = admin@yourdomain.com
# sender   = fail2ban@yourdomain.com
# action   = %(action_mwl)s

# Ignore your own IPs (space-separated)
ignoreip = 127.0.0.1/8 ::1
# ignoreip = 127.0.0.1/8 ::1 203.0.113.50
```

### 2.2 SSH Jail Configuration

Already created by `vps-setup.sh` at `/etc/fail2ban/jail.local`. To customize:

```bash
sudo nano /etc/fail2ban/jail.local
```

```ini
[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 3600
findtime = 600

# Use aggressive mode to catch more SSH attack patterns
mode     = aggressive
```

If you changed your SSH port (see section 3.3):

```ini
[sshd]
enabled  = true
port     = 2222
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 7200
```

### 2.3 Nginx Jails (Bad Bots, Auth Failures)

Create or add to `/etc/fail2ban/jail.local`:

```ini
# Block repeated HTTP auth failures
[nginx-http-auth]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 3
bantime  = 3600

# Block bots scanning for exploits (404 floods)
[nginx-botsearch]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 5
bantime  = 86400
findtime = 600

# Block bad bots based on user-agent patterns
[nginx-badbots]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 1
bantime  = 86400
```

Create the **bad bots filter** at `/etc/fail2ban/filter.d/nginx-badbots.conf`:

```ini
[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD).*" .* "(AhrefsBot|MJ12bot|SemrushBot|DotBot|BLEXBot|SearchmetricsBot)".*$
ignoreregex =
```

### 2.4 Custom Jail Examples

**Rate limit any URL path** — create `/etc/fail2ban/filter.d/nginx-req-limit.conf`:

```ini
[Definition]
failregex = limiting requests, excess:.* by zone.*client: <HOST>
ignoreregex =
```

Add the jail to `/etc/fail2ban/jail.local`:

```ini
# Ban IPs that trigger Nginx rate limiting
[nginx-req-limit]
enabled  = true
port     = http,https
filter   = nginx-req-limit
logpath  = /var/log/nginx/error.log
maxretry = 5
bantime  = 7200
findtime = 600
```

**Block WordPress login brute-force** — create `/etc/fail2ban/filter.d/nginx-wordpress.conf`:

```ini
[Definition]
failregex = ^<HOST> .* "POST /wp-login\.php
            ^<HOST> .* "POST /xmlrpc\.php
ignoreregex =
```

```ini
[nginx-wordpress]
enabled  = true
port     = http,https
filter   = nginx-wordpress
logpath  = /var/log/nginx/access.log
maxretry = 3
bantime  = 86400
```

After any jail changes, restart Fail2Ban:

```bash
# Test configuration first
sudo fail2ban-client --test

# Restart
sudo systemctl restart fail2ban
```

### 2.5 Check Banned IPs

```bash
# Overall status — lists all active jails
sudo fail2ban-client status

# Status of a specific jail (shows banned IPs)
sudo fail2ban-client status sshd

# Check all banned IPs across all jails
sudo fail2ban-client banned

# Check if a specific IP is banned
sudo fail2ban-client get sshd banip 198.51.100.0

# View the Fail2Ban log
sudo tail -50 /var/log/fail2ban.log

# Count total bans today
sudo grep "Ban " /var/log/fail2ban.log | grep "$(date +%Y-%m-%d)" | wc -l
```

### 2.6 Unban an IP

```bash
# Unban from a specific jail
sudo fail2ban-client set sshd unbanip 203.0.113.50

# Unban from all jails at once
sudo fail2ban-client unban 203.0.113.50

# Unban ALL IPs from all jails (use with caution)
sudo fail2ban-client unban --all
```

### 2.7 Fail2Ban with UFW Integration

By default, Fail2Ban uses iptables. To use UFW instead (recommended when UFW is your primary firewall):

Edit `/etc/fail2ban/jail.local`:

```ini
[DEFAULT]
banaction = ufw
```

Or create `/etc/fail2ban/action.d/ufw.conf` if it doesn't exist:

```ini
[Definition]
actionstart =
actionstop =
actioncheck =
actionban = ufw insert 1 deny from <ip> to any
actionunban = ufw delete deny from <ip> to any
```

Verify integration:

```bash
# Restart Fail2Ban
sudo systemctl restart fail2ban

# After a ban occurs, check UFW rules — you should see deny rules
sudo ufw status numbered
```

### 2.8 Log Monitoring

```bash
# Follow Fail2Ban log in real time
sudo tail -f /var/log/fail2ban.log

# Show recent bans
sudo grep "Ban " /var/log/fail2ban.log | tail -20

# Show recent unbans
sudo grep "Unban " /var/log/fail2ban.log | tail -20

# Summary of bans per jail
sudo awk '/Ban/ {print $NF}' /var/log/fail2ban.log | sort | uniq -c | sort -rn | head -20

# Top offending IPs
sudo awk '/Ban/ {print $NF}' /var/log/fail2ban.log | sort | uniq -c | sort -rn | head -10
```

---

## 3. SSH Hardening

> **Note:** `vps-setup.sh` already sets `PermitRootLogin prohibit-password`, `PasswordAuthentication no`, and `PubkeyAuthentication yes` via `/etc/ssh/sshd_config.d/99-custom.conf`. The following sections cover additional hardening.

### 3.1 Disable Root Login Completely

The setup script allows root login with SSH keys. To disable root login entirely:

```bash
sudo nano /etc/ssh/sshd_config.d/99-custom.conf
```

```
# Change from prohibit-password to no
PermitRootLogin no
```

```bash
# Always test config before reloading
sudo sshd -t && sudo systemctl reload sshd
```

> **⚠️ Warning:** Ensure your `deploy` user has sudo access before disabling root login.

### 3.2 Disable Password Authentication

Already handled by `vps-setup.sh`. Verify it's working:

```bash
# Verify password auth is disabled
sudo sshd -T | grep -i passwordauthentication
# Should output: passwordauthentication no

# Also verify key auth is enabled
sudo sshd -T | grep -i pubkeyauthentication
# Should output: pubkeyauthentication yes
```

### 3.3 Change Default SSH Port

**Pros:**
- Eliminates noise from automated bots scanning port 22
- Reduces log clutter from mass SSH brute-force attempts
- Adds a minor layer of obscurity

**Cons:**
- Security through obscurity — not a real defense on its own
- Easy to find with a port scan (nmap)
- May complicate your workflow (must remember/specify the port everywhere)
- Some corporate firewalls only allow outbound port 22

**If you decide to change it:**

```bash
# 1. Add the new port to UFW BEFORE changing SSH config
sudo ufw allow 2222/tcp

# 2. Edit SSH config
sudo nano /etc/ssh/sshd_config.d/99-custom.conf
```

```
Port 2222
```

```bash
# 3. Test and reload
sudo sshd -t && sudo systemctl reload sshd

# 4. Test connection on the NEW port (from a separate terminal!)
ssh -p 2222 deploy@your-server-ip

# 5. Only after confirming the new port works, remove old port
sudo ufw delete allow ssh
sudo ufw allow 2222/tcp comment 'SSH on custom port'

# 6. Update Fail2Ban jail
sudo nano /etc/fail2ban/jail.local
# Change port = ssh → port = 2222

sudo systemctl restart fail2ban
```

> **⚠️ Warning:** Always test the new port in a separate terminal before closing your current SSH session. Getting locked out of a VPS is painful.

### 3.4 SSH Key-Only Authentication

Generate a key pair on your **local machine** (not the server):

```bash
# Generate an Ed25519 key (recommended — faster and more secure than RSA)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Or RSA 4096-bit if Ed25519 isn't supported
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Copy the public key to your server
ssh-copy-id -i ~/.ssh/id_ed25519.pub deploy@your-server-ip

# Or manually add it on the server
echo "your-public-key-content" >> /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys
```

### 3.5 SSH Config Best Practices

Full recommended `/etc/ssh/sshd_config.d/99-custom.conf`:

```bash
# Authentication
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
AuthenticationMethods publickey

# Limit SSH to specific users
AllowUsers deploy

# Session settings
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30
MaxAuthTries 3
MaxSessions 3
MaxStartups 3:50:10

# Security
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
UsePAM yes

# Logging
LogLevel VERBOSE

# Only allow strong crypto (optional, advanced)
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
```

```bash
# Test the config
sudo sshd -t

# If no errors, reload
sudo systemctl reload sshd
```

> **Key settings explained:**
> - `ClientAliveInterval 300` — Server pings client every 5 minutes
> - `ClientAliveCountMax 2` — Disconnect after 2 missed pings (10 min idle timeout)
> - `MaxAuthTries 3` — Disconnect after 3 failed auth attempts
> - `MaxStartups 3:50:10` — Start dropping connections after 3 unauthenticated, 50% drop rate, max 10

### 3.6 Two-Factor Authentication (Optional)

Add TOTP (Google Authenticator) as a second factor:

```bash
# Install the PAM module
sudo apt install -y libpam-google-authenticator

# Configure it for your user (run as the user, not root)
su - deploy
google-authenticator
# Answer: y, y, y, n, y (recommended defaults)
# Save the QR code and emergency codes!
exit
```

Edit PAM configuration:

```bash
sudo nano /etc/pam.d/sshd
```

Add at the end:

```
auth required pam_google_authenticator.so
```

Edit SSH config:

```bash
sudo nano /etc/ssh/sshd_config.d/99-custom.conf
```

```
# Enable both key + TOTP
AuthenticationMethods publickey,keyboard-interactive
ChallengeResponseAuthentication yes
UsePAM yes
```

```bash
sudo sshd -t && sudo systemctl reload sshd
```

> **Note:** After enabling 2FA, you'll need both your SSH key AND the TOTP code to log in. Test in a separate terminal before closing your current session.

### 3.7 Limit SSH Users with AllowUsers

Restrict which users can SSH in:

```bash
sudo nano /etc/ssh/sshd_config.d/99-custom.conf
```

```
# Only these users can SSH in
AllowUsers deploy

# Allow multiple users
# AllowUsers deploy admin backup

# Allow a user only from specific IPs
# AllowUsers deploy@203.0.113.50 deploy@10.0.0.*
```

```bash
sudo sshd -t && sudo systemctl reload sshd
```

### 3.8 Idle Timeout Settings

```bash
sudo nano /etc/ssh/sshd_config.d/99-custom.conf
```

```
# Send a keepalive ping every 5 minutes
ClientAliveInterval 300

# Disconnect after 2 missed pings (total: 10 min idle timeout)
ClientAliveCountMax 2
```

```bash
sudo sshd -t && sudo systemctl reload sshd
```

You can also set a **server-side shell timeout** in `/etc/profile.d/timeout.sh`:

```bash
sudo tee /etc/profile.d/timeout.sh > /dev/null <<'EOF'
# Auto-logout after 15 minutes of inactivity
TMOUT=900
readonly TMOUT
export TMOUT
EOF
```

---

## 4. Nginx Security

> **Note:** `vps-setup.sh` installs Nginx but does not configure security headers or advanced protections. All items in this section require manual setup.

### 4.1 Security Headers

Create a shared headers file to include across your server blocks:

```bash
sudo nano /etc/nginx/snippets/security-headers.conf
```

```nginx
# Prevent clickjacking
add_header X-Frame-Options "SAMEORIGIN" always;

# Prevent MIME-type sniffing
add_header X-Content-Type-Options "nosniff" always;

# Enable XSS filter (legacy browsers)
add_header X-XSS-Protection "1; mode=block" always;

# Control referrer information
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# Permissions policy (restrict browser features)
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;

# Content Security Policy — customize per application
# Start with report-only to test, then enforce
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'self';" always;

# HTTP Strict Transport Security (only add if using SSL!)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

Include it in your server blocks:

```nginx
server {
    listen 443 ssl;
    server_name yourdomain.com;

    include snippets/security-headers.conf;

    # ... rest of config
}
```

### 4.2 Hide Nginx Version

```bash
sudo nano /etc/nginx/nginx.conf
```

Inside the `http` block:

```nginx
http {
    # Hide Nginx version from response headers and error pages
    server_tokens off;

    # ... rest of config
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Verify:

```bash
# Should NOT show the version number
curl -sI http://your-server-ip | grep -i server
# Expected: Server: nginx
# Not: Server: nginx/1.18.0
```

### 4.3 Rate Limiting in Nginx

Define rate limit zones in `/etc/nginx/nginx.conf` (inside the `http` block):

```nginx
http {
    # General request rate limit: 10 requests/second per IP
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;

    # Login/API rate limit: 5 requests/second per IP
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/s;

    # Connection limit: max 20 simultaneous connections per IP
    limit_conn_zone $binary_remote_addr zone=addr:10m;

    # Custom error page for rate-limited requests
    limit_req_status 429;
    limit_conn_status 429;
}
```

Apply in your server blocks:

```nginx
server {
    # Apply general rate limit (allow burst of 20 with delay)
    limit_req zone=general burst=20 nodelay;

    # Limit concurrent connections per IP
    limit_conn addr 20;

    # Stricter limit on login endpoints
    location /api/login {
        limit_req zone=login burst=5 nodelay;
        proxy_pass http://localhost:3000;
    }

    location /wp-login.php {
        limit_req zone=login burst=3 nodelay;
        # ... 
    }
}
```

> **Tip:** `burst=20 nodelay` allows up to 20 requests to be processed immediately above the rate, then enforces the limit. Without `nodelay`, excess requests are queued.

### 4.4 Block Bad Bots and Crawlers

Create a bot-blocking map in `/etc/nginx/conf.d/block-bots.conf`:

```nginx
map $http_user_agent $bad_bot {
    default 0;
    ~*AhrefsBot       1;
    ~*MJ12bot         1;
    ~*SemrushBot       1;
    ~*DotBot           1;
    ~*BLEXBot          1;
    ~*Sogou            1;
    ~*MegaIndex        1;
    ~*YandexBot        1;
    ~*serpstatbot      1;
    ~*DataForSeoBot    1;
    ~*PetalBot         1;
    ~*Bytespider       1;
    ~*GPTBot           1;
    ~*CCBot            1;
    ~*ClaudeBot        1;
    ""                 1;  # Block empty user-agents
}
```

Use in server blocks:

```nginx
server {
    if ($bad_bot) {
        return 403;
    }
    # ... rest of config
}
```

### 4.5 Block Access to Sensitive Files

Add to your server block:

```nginx
server {
    # Block access to hidden files (e.g., .env, .git)
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Block access to backup and config files
    location ~* \.(bak|conf|dist|env|ini|log|sh|sql|swp|tar\.gz|zip)$ {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Block common exploit paths
    location ~* /(wp-admin|wp-login|xmlrpc|phpmyadmin|admin|login\.php) {
        deny all;
        return 444;  # Close connection without response
    }

    # Block access to sensitive directories
    location ~* /(\.git|\.svn|\.env|node_modules|vendor) {
        deny all;
        return 404;
    }
}
```

### 4.6 DDoS Mitigation Basics

Add to `/etc/nginx/nginx.conf`:

```nginx
http {
    # Timeouts — drop slow/stalled connections
    client_body_timeout   10s;
    client_header_timeout 10s;
    keepalive_timeout     30s;
    send_timeout          10s;

    # Limit request body size (prevents large upload attacks)
    client_max_body_size 10m;

    # Buffer size limits
    client_body_buffer_size    16k;
    client_header_buffer_size  1k;
    large_client_header_buffers 4 8k;

    # Rate limit and connection limit (defined in section 4.3)
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_conn_zone $binary_remote_addr zone=addr:10m;
}
```

```nginx
server {
    limit_req zone=general burst=20 nodelay;
    limit_conn addr 20;

    # Return 444 (close connection) for suspicious requests
    location = /xmlrpc.php { return 444; }

    # Block requests with no Host header
    if ($host = '') {
        return 444;
    }
}
```

> **Note:** For serious DDoS protection, use a service like Cloudflare, AWS Shield, or your hosting provider's DDoS mitigation. Nginx-level protection handles small-scale attacks only.

### 4.7 Request Size Limits

```nginx
http {
    # Default: reject request bodies larger than 10MB
    client_max_body_size 10m;
}

server {
    # Override per-location for file uploads
    location /api/upload {
        client_max_body_size 50m;
        proxy_pass http://localhost:3000;
    }

    # Strict limit for login/API endpoints
    location /api/ {
        client_max_body_size 1m;
        proxy_pass http://localhost:3000;
    }
}
```

After all Nginx changes:

```bash
# Always test before reloading
sudo nginx -t

# Reload if test passes
sudo systemctl reload nginx
```

---

## 5. System Security

### 5.1 Automatic Security Updates

Already enabled by `vps-setup.sh` via `unattended-upgrades`. Verify and customize:

```bash
# Check if unattended-upgrades is installed and enabled
sudo apt-cache policy unattended-upgrades
systemctl status unattended-upgrades

# View current configuration
cat /etc/apt/apt.conf.d/50unattended-upgrades
```

Customize `/etc/apt/apt.conf.d/50unattended-upgrades`:

```bash
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

```
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

// Auto-remove unused dependencies
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Reboot automatically at 3 AM if required
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";

// Email notifications (optional)
// Unattended-Upgrade::Mail "admin@yourdomain.com";
// Unattended-Upgrade::MailReport "on-change";
```

Enable the auto-update timer:

```bash
sudo nano /etc/apt/apt.conf.d/20auto-upgrades
```

```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
```

```bash
# Test unattended-upgrades (dry run)
sudo unattended-upgrades --dry-run --debug
```

### 5.2 Non-Root User for Deployments

`vps-setup.sh` creates a `deploy` user. Verify and harden:

```bash
# Verify the deploy user exists and has sudo
id deploy
groups deploy
# Should show: deploy sudo

# Set up sudo without password for specific commands only (optional)
sudo visudo -f /etc/sudoers.d/deploy
```

```
# Allow deploy to restart services without a password
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl reload nginx
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl reload php*-fpm
deploy ALL=(ALL) NOPASSWD: /usr/sbin/nginx -t
```

```bash
# Ensure proper ownership of app directories
sudo chown -R deploy:deploy /var/www/apps
sudo chmod 755 /var/www/apps
```

### 5.3 File Permissions Best Practices

```bash
# Web root — owned by deploy, readable by nginx (www-data)
sudo chown -R deploy:www-data /var/www/apps
sudo find /var/www/apps -type d -exec chmod 755 {} \;
sudo find /var/www/apps -type f -exec chmod 644 {} \;

# Ensure .env files are not world-readable
sudo find /var/www/apps -name ".env" -exec chmod 600 {} \;
sudo find /var/www/apps -name ".env" -exec chown deploy:deploy {} \;

# SSH directory permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/id_*.pub

# Log files
sudo chmod 640 /var/log/nginx/*.log
sudo chmod 640 /var/log/auth.log

# Sensitive config files
sudo chmod 600 /etc/fail2ban/jail.local
sudo chmod 600 /root/credentials.txt
```

### 5.4 Disable Unused Services

```bash
# List all running services
systemctl list-units --type=service --state=running

# Common services to disable if not needed
sudo systemctl disable --now cups          # Printing
sudo systemctl disable --now avahi-daemon  # mDNS/Bonjour
sudo systemctl disable --now bluetooth    # Bluetooth (servers)
sudo systemctl disable --now ModemManager  # Modem
sudo systemctl disable --now snapd         # Snap packages

# Check for services listening on ports
sudo ss -tulnp

# List enabled services (will start on boot)
systemctl list-unit-files --state=enabled --type=service
```

### 5.5 Check for Open Ports

```bash
# Show all listening ports with process names
sudo ss -tulnp

# Same info with netstat (if installed)
sudo netstat -tulnp

# Check from outside your server (run on your local machine)
nmap -sT your-server-ip

# Verify UFW is blocking everything else
sudo ufw status verbose

# Quick one-liner: show listening ports and their programs
sudo ss -tulnp | awk 'NR>1 {print $1, $5, $7}' | column -t
```

Expected open ports for a typical VPS:

| Port | Service | Required? |
|------|---------|-----------|
| 22 (or custom) | SSH | ✅ Yes |
| 80 | HTTP (Nginx) | ✅ Yes |
| 443 | HTTPS (Nginx) | ✅ Yes |
| 3306 | MySQL | ⚠️ Only if external access needed |
| 5432 | PostgreSQL | ⚠️ Only if external access needed |
| 6379 | Redis | ⚠️ Only if external access needed |

> **Rule of thumb:** If a service only needs to be accessed locally (e.g., your Node.js app connecting to MySQL on the same server), bind it to `127.0.0.1` instead of opening a firewall port.

```bash
# Bind MySQL to localhost only (in /etc/mysql/mysql.conf.d/mysqld.cnf)
# bind-address = 127.0.0.1

# Bind Redis to localhost only (in /etc/redis/redis.conf)
# bind 127.0.0.1 ::1

# Bind PostgreSQL to localhost only (in /etc/postgresql/*/main/postgresql.conf)
# listen_addresses = 'localhost'
```

### 5.6 Audit Login Attempts

```bash
# Show last 20 successful logins
last -20

# Show last 20 failed login attempts
sudo lastb -20

# Show all currently logged-in users
who
w

# Check auth log for SSH attempts
sudo grep "Failed password" /var/log/auth.log | tail -20

# Count failed SSH attempts by IP
sudo grep "Failed password" /var/log/auth.log | \
    awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head -10

# Check for successful SSH logins
sudo grep "Accepted publickey" /var/log/auth.log | tail -20

# Show all sudo usage
sudo grep "sudo:" /var/log/auth.log | tail -20

# Check for unauthorized sudo attempts
sudo grep "NOT in sudoers" /var/log/auth.log

# Install and use auth log analyzer (optional)
sudo apt install -y logwatch
sudo logwatch --detail high --service sshd --range today
```

---

## 6. Security Checklist

Use this checklist after running `vps-setup.sh` and applying the hardening steps above.

### Firewall (UFW)

- [ ] UFW is enabled (`sudo ufw status` shows `active`)
- [ ] Default policies: deny incoming, allow outgoing
- [ ] Only required ports are open (SSH, HTTP, HTTPS)
- [ ] Database ports are restricted to specific IPs (not open to world)
- [ ] SSH is rate-limited (`sudo ufw limit ssh`)
- [ ] No unnecessary rules (`sudo ufw status numbered`)

### Fail2Ban

- [ ] Fail2Ban service is running (`sudo systemctl status fail2ban`)
- [ ] SSH jail is active (`sudo fail2ban-client status sshd`)
- [ ] Nginx jails are configured (if serving web traffic)
- [ ] `banaction = ufw` is set for UFW integration
- [ ] Your own IP is in `ignoreip` to prevent self-lockout

### SSH

- [ ] Root login is disabled (`PermitRootLogin no`)
- [ ] Password authentication is disabled (`PasswordAuthentication no`)
- [ ] Key-based authentication is working (test login as `deploy` user)
- [ ] `MaxAuthTries` is set to 3
- [ ] `AllowUsers` restricts SSH to known users
- [ ] Idle timeout is configured (`ClientAliveInterval` + `ClientAliveCountMax`)
- [ ] SSH config test passes (`sudo sshd -t`)

### Nginx

- [ ] `server_tokens off` is set (version hidden)
- [ ] Security headers are present (test with `curl -sI https://yourdomain.com`)
- [ ] Rate limiting is configured for login/API endpoints
- [ ] `.env`, `.git`, and hidden files are blocked
- [ ] Request body size is limited (`client_max_body_size`)
- [ ] Nginx config test passes (`sudo nginx -t`)

### System

- [ ] System packages are up to date (`sudo apt update && sudo apt list --upgradable`)
- [ ] `unattended-upgrades` is running (`systemctl status unattended-upgrades`)
- [ ] No unnecessary services are running
- [ ] Only expected ports are listening (`sudo ss -tulnp`)
- [ ] Databases are bound to `127.0.0.1` (if no external access needed)
- [ ] File permissions are correct (`.env` files are `600`, web root is `755/644`)
- [ ] `/root/credentials.txt` is `chmod 600`
- [ ] Swap file exists and is correctly permissioned (`ls -la /swapfile`)

### Access

- [ ] `deploy` user can SSH in with key authentication
- [ ] `deploy` user has sudo access
- [ ] Root cannot log in via SSH
- [ ] Password login is rejected (test: `ssh -o PubkeyAuthentication=no deploy@server`)

### Monitoring

- [ ] Auth log shows no unauthorized access (`sudo grep "Failed" /var/log/auth.log`)
- [ ] Fail2Ban is actively banning attackers (`sudo fail2ban-client status`)
- [ ] UFW log is enabled (`sudo ufw logging on`)
- [ ] Consider setting up external monitoring (UptimeRobot, Hetrixtools, etc.)

---

### Quick Audit Script

Run this one-liner to get a quick security overview of your server:

```bash
echo "=== UFW Status ===" && sudo ufw status verbose && \
echo -e "\n=== Fail2Ban Status ===" && sudo fail2ban-client status && \
echo -e "\n=== Open Ports ===" && sudo ss -tulnp && \
echo -e "\n=== SSH Config ===" && sudo sshd -T 2>/dev/null | grep -E "^(permitrootlogin|passwordauthentication|pubkeyauthentication|allowusers|maxauthtries|port) " && \
echo -e "\n=== Logged In Users ===" && who && \
echo -e "\n=== Failed SSH Today ===" && sudo grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date +%b\ %e)" | wc -l && \
echo -e "\n=== Last 5 Logins ===" && last -5
```

---

> **Further Reading:**
> - [Ubuntu Server Security Guide](https://ubuntu.com/server/docs/security-introduction)
> - [Nginx Hardening Guide](https://docs.nginx.com/nginx/admin-guide/security-controls/)
> - [Fail2Ban Documentation](https://www.fail2ban.org/wiki/index.php/Main_Page)
> - [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
> - [Security Headers Scanner](https://securityheaders.com/)
