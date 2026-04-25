# SSL Troubleshooting Guide

Solutions for common SSL/TLS certificate issues on your VPS.

> **Related Guides:**
> - [SSL Setup Guide (Start Here)](SSL-SETUP-GUIDE.md)
> - [SSL Wildcard & Multi-Domain](SSL-WILDCARD-AND-MULTI-DOMAIN.md)

---

## Table of Contents

1. [Diagnostic Commands](#diagnostic-commands)
2. [Certbot Errors](#certbot-errors)
3. [Nginx SSL Errors](#nginx-ssl-errors)
4. [Browser Errors](#browser-errors)
5. [Renewal Failures](#renewal-failures)
6. [Mixed Content Issues](#mixed-content-issues)
7. [SSL Rating & Hardening](#ssl-rating--hardening)
8. [Nuclear Option — Start Over](#nuclear-option--start-over)

---

## Diagnostic Commands

Run these first to understand your current SSL state:

```bash
# List all certificates and their status
sudo certbot certificates

# Check Nginx configuration syntax
sudo nginx -t

# Check if Nginx is running
sudo systemctl status nginx

# Check which ports are listening
sudo ss -tulpn | grep -E ':80|:443'

# Check certificate details for a domain
echo | openssl s_client -connect yourdomain.com:443 -servername yourdomain.com 2>/dev/null | openssl x509 -noout -text | head -20

# Check certificate expiry date
echo | openssl s_client -connect yourdomain.com:443 -servername yourdomain.com 2>/dev/null | openssl x509 -noout -enddate

# Check DNS is pointing to this server
dig +short yourdomain.com

# Check Certbot logs
sudo cat /var/log/letsencrypt/letsencrypt.log | tail -50
```

---

## Certbot Errors

### Error: "The requested nginx plugin does not appear to be installed"

```bash
# Install the Nginx plugin
sudo apt install python3-certbot-nginx -y

# Or if using snap
sudo snap set certbot trust-plugin-with-root=ok
sudo snap install certbot-dns-cloudflare  # or other plugins as needed
```

### Error: "Could not automatically find a matching server block"

Certbot can't find a Nginx config with a matching `server_name`.

```bash
# Check your Nginx configs
sudo grep -r "server_name" /etc/nginx/sites-enabled/

# Make sure server_name matches your domain EXACTLY
sudo nano /etc/nginx/sites-available/yourapp
# server_name yourdomain.com www.yourdomain.com;

# Test and reload
sudo nginx -t && sudo systemctl reload nginx

# Try again
sudo certbot --nginx -d yourdomain.com
```

### Error: "Challenge failed for domain" / "Connection refused"

Let's Encrypt can't reach your server on port 80.

```bash
# 1. Check firewall
sudo ufw allow 80
sudo ufw allow 443
sudo ufw status

# 2. Check Nginx is listening on port 80
sudo ss -tulpn | grep :80

# 3. Make sure Nginx is running
sudo systemctl start nginx
sudo systemctl status nginx

# 4. Test from outside (from your local machine)
curl -I http://yourdomain.com

# 5. Check DNS points to this server
dig +short yourdomain.com
# Must return YOUR VPS IP address
```

### Error: "DNS problem: NXDOMAIN looking up A for yourdomain.com"

DNS is not configured or hasn't propagated yet.

```bash
# Check DNS
dig +short yourdomain.com

# If empty or wrong IP, fix your DNS settings at your domain registrar
# Wait for propagation (can take up to 48 hours, usually 5-30 minutes)

# Check propagation status online:
# https://www.whatsmydns.net/#A/yourdomain.com
```

### Error: "Too many certificates already issued"

You've hit Let's Encrypt's rate limit.

```bash
# Check existing certificates
sudo certbot certificates

# Options:
# 1. Wait (rate limit resets after 7 days)
# 2. Use --expand to modify existing certificate instead of creating new one
sudo certbot --nginx --expand -d yourdomain.com -d www.yourdomain.com

# 3. Use staging server for testing (not real certificate, but no rate limit)
sudo certbot --nginx -d yourdomain.com --staging
```

### Error: "Unauthorized" / "Invalid response"

```bash
# Make sure .well-known/acme-challenge is accessible
# Test it manually:
mkdir -p /var/www/html/.well-known/acme-challenge
echo "test" > /var/www/html/.well-known/acme-challenge/test

# Check from outside
curl http://yourdomain.com/.well-known/acme-challenge/test
# Should return "test"

# If blocked, check Nginx isn't denying access to hidden directories
# Make sure this is NOT in your config:
# location ~ /\. { deny all; }
# Or add an exception BEFORE the deny rule:
# location ^~ /.well-known/acme-challenge/ { allow all; }
```

Add this to your Nginx config if ACME challenges are being blocked:

```nginx
# Allow Let's Encrypt ACME challenges
location ^~ /.well-known/acme-challenge/ {
    allow all;
    root /var/www/html;
}
```

---

## Nginx SSL Errors

### Error: "ssl_certificate: no such file"

```bash
# Check if certificate files exist
sudo ls -la /etc/letsencrypt/live/yourdomain.com/

# If missing, request a new certificate
sudo certbot --nginx -d yourdomain.com

# If the live directory exists but files are broken (symlinks)
sudo ls -la /etc/letsencrypt/live/yourdomain.com/
# They should be symlinks to ../archive/yourdomain.com/

# Check archive directory
sudo ls -la /etc/letsencrypt/archive/yourdomain.com/
```

### Error: "ssl_certificate_key: doesn't match"

The certificate and private key don't match. This can happen if you mixed up files.

```bash
# Verify they match (modulus should be the same)
sudo openssl x509 -noout -modulus -in /etc/letsencrypt/live/yourdomain.com/fullchain.pem | md5sum
sudo openssl rsa -noout -modulus -in /etc/letsencrypt/live/yourdomain.com/privkey.pem | md5sum

# If they don't match, delete and re-request
sudo certbot delete --cert-name yourdomain.com
sudo certbot --nginx -d yourdomain.com
```

### Error: "nginx: [emerg] cannot load certificate"

```bash
# Check file permissions
sudo ls -la /etc/letsencrypt/live/yourdomain.com/

# Fix permissions if needed
sudo chmod 755 /etc/letsencrypt/live/
sudo chmod 755 /etc/letsencrypt/archive/

# Make sure Nginx can read the files
sudo nginx -t
```

### Nginx Won't Start After SSL Changes

```bash
# Find the exact error
sudo nginx -t

# Check Nginx error log
sudo tail -20 /var/log/nginx/error.log

# Common fix: remove the broken config, restore from backup
ls /etc/nginx/sites-available/*.bak*
# Certbot creates backups before modifying configs

# Or disable the problematic site temporarily
sudo rm /etc/nginx/sites-enabled/yourapp
sudo nginx -t && sudo systemctl start nginx
# Then fix the config and re-enable
```

---

## Browser Errors

### "Your connection is not private" (NET::ERR_CERT_AUTHORITY_INVALID)

Using a self-signed or staging certificate.

```bash
# Check if you accidentally used staging
sudo certbot certificates
# Look for "INVALID" or "FAKE" in certificate details

# If staging, re-request without --staging
sudo certbot delete --cert-name yourdomain.com
sudo certbot --nginx -d yourdomain.com
```

### "Certificate has expired" (NET::ERR_CERT_DATE_INVALID)

```bash
# Check expiry
sudo certbot certificates

# Renew
sudo certbot renew

# If renewal fails, force renewal
sudo certbot renew --force-renewal

# Reload Nginx after renewal
sudo systemctl reload nginx
```

### "Certificate name mismatch" (SSL_ERROR_BAD_CERT_DOMAIN)

The certificate doesn't cover the domain you're visiting.

```bash
# Check what domains the certificate covers
sudo certbot certificates

# If www is missing, expand the certificate
sudo certbot --nginx --expand -d yourdomain.com -d www.yourdomain.com

# Make sure Nginx server_name matches
sudo grep -r "server_name" /etc/nginx/sites-enabled/
```

### "ERR_TOO_MANY_REDIRECTS"

Infinite redirect loop between HTTP and HTTPS.

```bash
# Check your Nginx config for duplicate redirects
sudo cat /etc/nginx/sites-enabled/yourapp

# Common cause: both the HTTP and HTTPS blocks have "return 301"
# Fix: Only the HTTP (port 80) block should redirect to HTTPS

# If using Cloudflare, check SSL mode:
# Set to "Full (strict)" — not "Flexible"
# Flexible mode causes Cloudflare → HTTP → Nginx redirect → HTTPS → Cloudflare loop
```

---

## Renewal Failures

### Check Renewal Status

```bash
# Test renewal
sudo certbot renew --dry-run

# Check renewal config
sudo cat /etc/letsencrypt/renewal/yourdomain.com.conf

# Check certbot timer
sudo systemctl status certbot.timer
sudo systemctl list-timers | grep certbot
```

### "Attempting to renew cert... failed"

```bash
# Check the log for details
sudo tail -50 /var/log/letsencrypt/letsencrypt.log

# Common causes:
# 1. Port 80 blocked → sudo ufw allow 80
# 2. Nginx not running → sudo systemctl start nginx
# 3. DNS changed → dig +short yourdomain.com
# 4. Rate limited → wait and retry
```

### Certbot Timer Not Running

```bash
# Enable and start the timer
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Or add cron job as fallback
sudo crontab -e
# Add this line:
# 0 3 * * * certbot renew --quiet --deploy-hook "systemctl reload nginx"
```

---

## Mixed Content Issues

After enabling HTTPS, your site may load but show warnings about "mixed content" (HTTP resources on an HTTPS page).

### Find Mixed Content

```bash
# Check your site's HTML for http:// references
grep -r "http://" /var/www/apps/yourapp/build/ 2>/dev/null | grep -v "https://"
grep -r "http://" /var/www/apps/yourapp/public/ 2>/dev/null | grep -v "https://"
```

### Common Fixes

**React / Frontend apps:** Rebuild with HTTPS URLs

```bash
# In .env or environment variables
REACT_APP_API_URL=https://api.yourdomain.com  # not http://
```

**PHP apps:** Update base URL

```php
// config.php or .env
define('BASE_URL', 'https://yourdomain.com');
```

**Laravel:**

```env
# .env
APP_URL=https://yourdomain.com
```

**Nginx header to upgrade insecure requests:**

```nginx
add_header Content-Security-Policy "upgrade-insecure-requests" always;
```

---

## SSL Rating & Hardening

Get an **A+** rating on [SSL Labs](https://www.ssllabs.com/ssltest/).

### Create Strong SSL Configuration

```bash
sudo nano /etc/nginx/snippets/ssl-hardening.conf
```

```nginx
# Strong SSL configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# HSTS (force HTTPS for 1 year, including subdomains)
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# Session settings
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
```

Include it in your server block:

```nginx
server {
    listen 443 ssl http2;
    # ...

    include snippets/ssl-hardening.conf;

    # ... rest of config
}
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Generate Strong DH Parameters

```bash
# This takes a few minutes
sudo openssl dhparam -out /etc/nginx/dhparam.pem 2048
```

Add to your SSL config:

```nginx
ssl_dhparam /etc/nginx/dhparam.pem;
```

---

## Nuclear Option — Start Over

If everything is broken and you want to start fresh:

```bash
# 1. Delete all certificates
sudo certbot delete --cert-name yourdomain.com

# 2. Remove Certbot modifications from Nginx configs
# Check for backups
ls /etc/nginx/sites-available/*.bak*

# 3. Rewrite your Nginx config (use templates from nginx/ folder)
sudo nano /etc/nginx/sites-available/yourapp

# 4. Test and reload Nginx
sudo nginx -t && sudo systemctl reload nginx

# 5. Request fresh certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# 6. Test
curl -I https://yourdomain.com
```

### Complete Certbot Reset

```bash
# Remove all Certbot data (last resort)
sudo certbot delete --cert-name yourdomain.com
sudo rm -rf /etc/letsencrypt/renewal/yourdomain.com.conf
sudo rm -rf /etc/letsencrypt/archive/yourdomain.com/
sudo rm -rf /etc/letsencrypt/live/yourdomain.com/

# Reinstall Certbot
sudo snap remove certbot
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# Start fresh
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

---

## Quick Troubleshooting Checklist

When SSL isn't working, check in this order:

```
1. ✅ DNS points to your server          → dig +short yourdomain.com
2. ✅ Ports 80/443 open in firewall      → sudo ufw status
3. ✅ Nginx is running                    → sudo systemctl status nginx
4. ✅ Nginx config is valid               → sudo nginx -t
5. ✅ Certificate exists                  → sudo certbot certificates
6. ✅ Certificate not expired             → check expiry date above
7. ✅ Certificate covers the domain       → check domain list above
8. ✅ No redirect loops                   → curl -I http://yourdomain.com
9. ✅ No mixed content                    → browser console (F12)
10. ✅ Renewal is scheduled               → sudo systemctl status certbot.timer
```

---

> **Back to:** [SSL Setup Guide](SSL-SETUP-GUIDE.md) | [Wildcard & Multi-Domain](SSL-WILDCARD-AND-MULTI-DOMAIN.md)
