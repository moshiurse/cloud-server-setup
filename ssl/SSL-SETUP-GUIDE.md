# SSL/TLS Certificate Guide — Let's Encrypt with Certbot

Complete guide to securing your VPS-hosted applications with free SSL/TLS certificates from [Let's Encrypt](https://letsencrypt.org/).

> **Related Guides:**
> - [SSL for Wildcard & Multi-Domain](SSL-WILDCARD-AND-MULTI-DOMAIN.md)
> - [SSL Troubleshooting](SSL-TROUBLESHOOTING.md)

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Install Certbot](#install-certbot)
3. [SSL for Nginx (Recommended)](#ssl-for-nginx-recommended)
4. [SSL for Apache](#ssl-for-apache)
5. [Standalone Mode (No Web Server)](#standalone-mode)
6. [Verify SSL Installation](#verify-ssl-installation)
7. [Auto-Renewal Setup](#auto-renewal-setup)
8. [Force HTTPS Redirect](#force-https-redirect)
9. [SSL for Multiple Domains on Same Server](#ssl-for-multiple-domains-on-same-server)
10. [Revoking & Deleting Certificates](#revoking--deleting-certificates)
11. [How Let's Encrypt Works](#how-lets-encrypt-works)

---

## Prerequisites

Before requesting an SSL certificate, make sure:

- [x] You have a **domain name** pointed to your VPS IP (A record in DNS)
- [x] **DNS propagation is complete** (can take up to 48 hours, usually minutes)
- [x] **Port 80 and 443** are open in your firewall
- [x] **Nginx** (or Apache) is installed and running
- [x] Your site is accessible via `http://yourdomain.com`

### Check DNS is Pointing Correctly

```bash
# Check A record
dig +short yourdomain.com
# Should return your VPS IP, e.g., 123.45.67.89

# Or use nslookup
nslookup yourdomain.com
```

### Ensure Firewall Allows HTTP/HTTPS

```bash
sudo ufw allow 80
sudo ufw allow 443
sudo ufw status
```

---

## Install Certbot

### Ubuntu 22.04+ (Snap — Recommended)

```bash
# Remove old certbot if exists
sudo apt remove certbot -y

# Install via snap (always latest version)
sudo snap install --classic certbot

# Create symlink so you can run "certbot" from anywhere
sudo ln -s /snap/bin/certbot /usr/bin/certbot
```

### Ubuntu 20.04 / Debian (APT)

```bash
sudo apt update
sudo apt install certbot -y

# Install the Nginx plugin
sudo apt install python3-certbot-nginx -y

# Or Apache plugin
# sudo apt install python3-certbot-apache -y
```

### Verify Installation

```bash
certbot --version
```

---

## SSL for Nginx (Recommended)

This is the easiest method. Certbot automatically modifies your Nginx config to enable HTTPS.

### Step 1: Make Sure Nginx Config Exists

Your site should already have a config in `/etc/nginx/sites-available/`:

```bash
# List your site configs
ls /etc/nginx/sites-available/

# Make sure your site config has the correct server_name
sudo grep -r "server_name" /etc/nginx/sites-available/
```

The `server_name` in your Nginx config **must match** the domain you're requesting the certificate for.

### Step 2: Request Certificate

```bash
# Single domain
sudo certbot --nginx -d yourdomain.com

# Domain + www subdomain (most common)
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Multiple subdomains
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com -d api.yourdomain.com
```

### Step 3: Follow the Prompts

```
1. Enter email address → your@email.com (for renewal notifications)
2. Agree to Terms of Service → Y
3. Share email with EFF → N (optional)
4. Redirect HTTP to HTTPS → 2 (Redirect — recommended)
```

### Step 4: Verify

```bash
# Test your site
curl -I https://yourdomain.com

# You should see:
# HTTP/2 200
# ...
```

### What Certbot Does to Your Nginx Config

Certbot automatically adds an HTTPS server block to your config:

```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # ... your existing location blocks ...
}
```

And adds a redirect in the HTTP block:

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

---

## SSL for Apache

If you're running Apache instead of Nginx:

```bash
# Install Apache plugin
sudo apt install python3-certbot-apache -y

# Request certificate
sudo certbot --apache -d yourdomain.com -d www.yourdomain.com

# Reload Apache
sudo systemctl reload apache2
```

---

## Standalone Mode

Use this when you **don't have a web server running**, or need a certificate before setting up Nginx/Apache. Certbot temporarily starts its own web server on port 80.

```bash
# Stop Nginx/Apache first (port 80 must be free)
sudo systemctl stop nginx

# Request certificate
sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com

# Start Nginx/Apache again
sudo systemctl start nginx
```

The certificate files will be saved to:
```
/etc/letsencrypt/live/yourdomain.com/fullchain.pem   → Certificate + chain
/etc/letsencrypt/live/yourdomain.com/privkey.pem      → Private key
```

You then need to manually configure your web server to use these files.

---

## Verify SSL Installation

### From Command Line

```bash
# Check certificate details
sudo certbot certificates

# Output shows:
#   Certificate Name: yourdomain.com
#   Domains: yourdomain.com www.yourdomain.com
#   Expiry Date: 2025-07-25 (VALID: 89 days)
#   Certificate Path: /etc/letsencrypt/live/yourdomain.com/fullchain.pem
#   Private Key Path: /etc/letsencrypt/live/yourdomain.com/privkey.pem
```

### Test with OpenSSL

```bash
# Check certificate from server
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com < /dev/null 2>/dev/null | openssl x509 -noout -dates -subject

# Check certificate expiry
echo | openssl s_client -connect yourdomain.com:443 -servername yourdomain.com 2>/dev/null | openssl x509 -noout -enddate
```

### Test with curl

```bash
# Verbose SSL check
curl -vI https://yourdomain.com 2>&1 | grep -E "SSL|certificate|expire|subject"
```

### Online Tools

- [SSL Labs Test](https://www.ssllabs.com/ssltest/) — Comprehensive SSL grading (A+ is ideal)
- [Why No Padlock](https://www.whynopadlock.com/) — Find mixed content issues

---

## Auto-Renewal Setup

Let's Encrypt certificates expire every **90 days**. Certbot sets up auto-renewal automatically.

### Verify Auto-Renewal is Configured

```bash
# Check certbot timer (systemd)
sudo systemctl status certbot.timer

# Or check snap timer
sudo snap list certbot

# Or check crontab
sudo crontab -l | grep certbot
cat /etc/cron.d/certbot 2>/dev/null
```

### Test Renewal (Dry Run)

```bash
# This simulates renewal without making changes
sudo certbot renew --dry-run
```

If the dry run succeeds, auto-renewal is working correctly.

### Manual Renewal

```bash
# Renew all certificates that are near expiry
sudo certbot renew

# Force renewal (even if not near expiry)
sudo certbot renew --force-renewal

# Renew and reload Nginx
sudo certbot renew --deploy-hook "systemctl reload nginx"
```

### Custom Renewal Hook

To automatically reload Nginx after every renewal:

```bash
# Create a deploy hook
sudo nano /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
```

```bash
#!/bin/bash
systemctl reload nginx
```

```bash
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
```

---

## Force HTTPS Redirect

After SSL is installed, you should redirect all HTTP traffic to HTTPS.

### Nginx

If Certbot didn't add the redirect automatically, edit your Nginx config:

```nginx
# HTTP → HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name yourdomain.com www.yourdomain.com;
    return 301 https://$server_name$request_uri;
}
```

Then reload:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Redirect www to non-www (or vice versa)

```nginx
# Redirect www → non-www
server {
    listen 443 ssl http2;
    server_name www.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    return 301 https://yourdomain.com$request_uri;
}
```

---

## SSL for Multiple Domains on Same Server

If you host multiple apps on one VPS, each domain gets its own certificate.

### Option 1: Separate Certificates (Recommended)

```bash
# App 1
sudo certbot --nginx -d app1.yourdomain.com

# App 2
sudo certbot --nginx -d app2.yourdomain.com

# App 3 (different domain entirely)
sudo certbot --nginx -d anotherdomain.com -d www.anotherdomain.com
```

Each domain's Nginx config is updated independently.

### Option 2: Single Certificate for Multiple Domains

```bash
sudo certbot --nginx \
  -d yourdomain.com \
  -d www.yourdomain.com \
  -d api.yourdomain.com \
  -d admin.yourdomain.com
```

> **Note:** All domains in a single certificate must point to the same server.

---

## Revoking & Deleting Certificates

### List All Certificates

```bash
sudo certbot certificates
```

### Revoke a Certificate

```bash
# Revoke (tells Let's Encrypt it's no longer valid)
sudo certbot revoke --cert-name yourdomain.com
```

### Delete a Certificate

```bash
# Delete from server (after revoking or if no longer needed)
sudo certbot delete --cert-name yourdomain.com
```

### Remove Certbot Changes from Nginx

If you need to undo what Certbot added to your Nginx config:

```bash
# Certbot keeps backups
ls /etc/nginx/sites-available/*.bak* 2>/dev/null

# Or manually remove the SSL server block and redirect from your config
sudo nano /etc/nginx/sites-available/yourapp
sudo nginx -t && sudo systemctl reload nginx
```

---

## How Let's Encrypt Works

### The ACME Challenge

When you request a certificate, Let's Encrypt verifies you control the domain:

1. **HTTP-01 Challenge** (default): Certbot places a temporary file at `http://yourdomain.com/.well-known/acme-challenge/TOKEN`. Let's Encrypt fetches this file to verify domain ownership.

2. **DNS-01 Challenge** (for wildcards): You add a TXT record to your DNS. Required for wildcard certificates (`*.yourdomain.com`). See [Wildcard Guide](SSL-WILDCARD-AND-MULTI-DOMAIN.md).

### Certificate Files Explained

```
/etc/letsencrypt/live/yourdomain.com/
├── fullchain.pem    → Your certificate + intermediate certificates (use this in Nginx)
├── privkey.pem      → Your private key (use this in Nginx)
├── cert.pem         → Your certificate only
└── chain.pem        → Intermediate certificates only
```

### Rate Limits

Let's Encrypt has rate limits to prevent abuse:

| Limit | Value |
|-------|-------|
| Certificates per domain | 50 per week |
| Duplicate certificates | 5 per week |
| Failed validations | 5 per hour |
| Accounts per IP | 10 per 3 hours |

Use `--dry-run` for testing to avoid hitting limits:

```bash
sudo certbot --nginx -d yourdomain.com --dry-run
```

---

## Quick Reference

```bash
# Install Certbot
sudo snap install --classic certbot

# Get certificate (Nginx)
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Test renewal
sudo certbot renew --dry-run

# List certificates
sudo certbot certificates

# Renew manually
sudo certbot renew

# Delete certificate
sudo certbot delete --cert-name yourdomain.com
```

---

> **Next:** [Wildcard & Multi-Domain SSL](SSL-WILDCARD-AND-MULTI-DOMAIN.md) | [SSL Troubleshooting](SSL-TROUBLESHOOTING.md)
