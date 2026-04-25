# SSL Wildcard & Multi-Domain Certificate Guide

Guide for setting up wildcard certificates (`*.yourdomain.com`) and managing SSL for complex multi-domain setups.

> **Related Guides:**
> - [SSL Setup Guide (Start Here)](SSL-SETUP-GUIDE.md)
> - [SSL Troubleshooting](SSL-TROUBLESHOOTING.md)

---

## Table of Contents

1. [When You Need This Guide](#when-you-need-this-guide)
2. [Wildcard Certificate Setup](#wildcard-certificate-setup)
3. [DNS Providers & Plugins](#dns-providers--plugins)
4. [Cloudflare DNS Plugin (Most Popular)](#cloudflare-dns-plugin)
5. [DigitalOcean DNS Plugin](#digitalocean-dns-plugin)
6. [Manual DNS Challenge](#manual-dns-challenge)
7. [Auto-Renewal for Wildcard Certificates](#auto-renewal-for-wildcard-certificates)
8. [Multi-Domain SAN Certificate](#multi-domain-san-certificate)
9. [Combining Wildcard + Specific Domains](#combining-wildcard--specific-domains)
10. [Nginx Config for Wildcard SSL](#nginx-config-for-wildcard-ssl)

---

## When You Need This Guide

| Scenario | Certificate Type | Guide |
|----------|-----------------|-------|
| Single domain (`yourdomain.com`) | Standard | [SSL Setup Guide](SSL-SETUP-GUIDE.md) |
| Domain + www (`yourdomain.com` + `www`) | Standard | [SSL Setup Guide](SSL-SETUP-GUIDE.md) |
| All subdomains (`*.yourdomain.com`) | **Wildcard** | This guide |
| Multiple different domains | **Multi-domain (SAN)** | This guide |
| Wildcard + root domain | **Wildcard + SAN** | This guide |

---

## Wildcard Certificate Setup

Wildcard certificates cover `*.yourdomain.com` — any subdomain like `app.yourdomain.com`, `api.yourdomain.com`, `admin.yourdomain.com`, etc.

### Important Notes

- Wildcard certificates **require DNS-01 challenge** (not HTTP-01)
- You need to add a DNS TXT record to prove domain ownership
- `*.yourdomain.com` does **NOT** cover `yourdomain.com` itself — you need both
- `*.yourdomain.com` does **NOT** cover `*.sub.yourdomain.com` (no nested wildcards)

---

## DNS Providers & Plugins

Certbot has plugins for automatic DNS record management. This is the recommended approach because it enables fully automated renewal.

### Supported DNS Providers

| Provider | Plugin |
|----------|--------|
| Cloudflare | `certbot-dns-cloudflare` |
| DigitalOcean | `certbot-dns-digitalocean` |
| AWS Route 53 | `certbot-dns-route53` |
| Google Cloud DNS | `certbot-dns-google` |
| Linode | `certbot-dns-linode` |
| Namecheap | Manual (no official plugin) |
| GoDaddy | Manual (no official plugin) |

---

## Cloudflare DNS Plugin

### Step 1: Install the Plugin

```bash
# Via snap (if Certbot installed via snap)
sudo snap set certbot trust-plugin-with-root=ok
sudo snap install certbot-dns-cloudflare

# Via pip (if Certbot installed via apt)
sudo apt install python3-certbot-dns-cloudflare -y
```

### Step 2: Get Cloudflare API Token

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token**
3. Use the **Edit zone DNS** template
4. Set permissions:
   - Zone → DNS → Edit
   - Zone → Zone → Read
5. Set zone resources: Include → Specific zone → `yourdomain.com`
6. Create the token and copy it

### Step 3: Create Credentials File

```bash
sudo mkdir -p /etc/letsencrypt/cloudflare
sudo nano /etc/letsencrypt/cloudflare/credentials.ini
```

```ini
# Cloudflare API Token
dns_cloudflare_api_token = YOUR_CLOUDFLARE_API_TOKEN_HERE
```

```bash
# Secure the file (important!)
sudo chmod 600 /etc/letsencrypt/cloudflare/credentials.ini
```

### Step 4: Request Wildcard Certificate

```bash
# Wildcard + root domain
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
  -d yourdomain.com \
  -d "*.yourdomain.com"
```

### Step 5: Configure Nginx

```bash
# Update your Nginx config to use the new certificate
sudo nano /etc/nginx/sites-available/yourapp
```

Add the SSL paths:
```nginx
ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

---

## DigitalOcean DNS Plugin

### Step 1: Install the Plugin

```bash
# Via snap
sudo snap set certbot trust-plugin-with-root=ok
sudo snap install certbot-dns-digitalocean

# Via apt
sudo apt install python3-certbot-dns-digitalocean -y
```

### Step 2: Get DigitalOcean API Token

1. Go to [DigitalOcean API](https://cloud.digitalocean.com/account/api/tokens)
2. Generate a new **Personal Access Token** with read+write scope

### Step 3: Create Credentials File

```bash
sudo mkdir -p /etc/letsencrypt/digitalocean
sudo nano /etc/letsencrypt/digitalocean/credentials.ini
```

```ini
dns_digitalocean_token = YOUR_DIGITALOCEAN_API_TOKEN_HERE
```

```bash
sudo chmod 600 /etc/letsencrypt/digitalocean/credentials.ini
```

### Step 4: Request Wildcard Certificate

```bash
sudo certbot certonly \
  --dns-digitalocean \
  --dns-digitalocean-credentials /etc/letsencrypt/digitalocean/credentials.ini \
  -d yourdomain.com \
  -d "*.yourdomain.com"
```

---

## Manual DNS Challenge

If your DNS provider doesn't have a Certbot plugin, use the manual DNS challenge.

> ⚠️ **Downside:** Cannot auto-renew. You must repeat this process every 90 days.

### Step 1: Request Certificate

```bash
sudo certbot certonly \
  --manual \
  --preferred-challenges dns \
  -d yourdomain.com \
  -d "*.yourdomain.com"
```

### Step 2: Add DNS TXT Record

Certbot will display something like:

```
Please deploy a DNS TXT record under the name:
_acme-challenge.yourdomain.com
with the following value:
gfj9Xq...Rg5nTzG-ABC123xyz

Before continuing, verify the TXT record has been deployed.
```

Go to your DNS provider's dashboard and add:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| TXT | `_acme-challenge` | `gfj9Xq...Rg5nTzG-ABC123xyz` | 300 |

### Step 3: Verify DNS Propagation

```bash
# Wait 1-2 minutes, then verify
dig -t TXT _acme-challenge.yourdomain.com +short

# Should return the value you added
```

### Step 4: Continue Certbot

Press Enter in the Certbot prompt once the TXT record is propagated.

> **Tip:** For wildcard + root domain, Certbot will ask you to create **two** TXT records with the same name `_acme-challenge`. Add both values — most DNS providers allow multiple TXT records with the same name.

---

## Auto-Renewal for Wildcard Certificates

### With DNS Plugin (Automatic)

If you used a DNS plugin (Cloudflare, DigitalOcean, etc.), renewal is fully automatic:

```bash
# Test renewal
sudo certbot renew --dry-run
```

The existing certbot timer/cron will handle renewal automatically.

### With Manual DNS (Not Automatic)

Manual DNS challenges cannot auto-renew. Options:

**Option A:** Switch to a DNS plugin (recommended)

**Option B:** Create a reminder and renew manually every 60-80 days:

```bash
# Manual renewal (will prompt for new DNS TXT records)
sudo certbot renew --manual
```

**Option C:** Use [acme.sh](https://github.com/acmesh-official/acme.sh) which has built-in API support for more DNS providers.

---

## Multi-Domain SAN Certificate

A SAN (Subject Alternative Name) certificate covers multiple different domains in one certificate.

```bash
# Multiple different domains in one certificate
sudo certbot --nginx \
  -d domain1.com \
  -d www.domain1.com \
  -d domain2.com \
  -d www.domain2.com \
  -d domain3.com
```

### Expanding an Existing Certificate

To add more domains to an existing certificate:

```bash
sudo certbot --nginx --expand \
  -d yourdomain.com \
  -d www.yourdomain.com \
  -d newsubdomain.yourdomain.com
```

---

## Combining Wildcard + Specific Domains

```bash
# Wildcard + root domain + specific other domains
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
  -d yourdomain.com \
  -d "*.yourdomain.com" \
  -d anotherdomain.com \
  -d www.anotherdomain.com
```

---

## Nginx Config for Wildcard SSL

Use a single Nginx config to handle all subdomains:

```nginx
# Catch-all for subdomains — each proxied to a different port
# /etc/nginx/sites-available/wildcard

# App 1: app1.yourdomain.com → port 3001
server {
    listen 443 ssl http2;
    server_name app1.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# App 2: app2.yourdomain.com → port 3002
server {
    listen 443 ssl http2;
    server_name app2.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://localhost:3002;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# HTTP → HTTPS redirect for all subdomains
server {
    listen 80;
    server_name *.yourdomain.com yourdomain.com;
    return 301 https://$host$request_uri;
}
```

---

## Quick Reference

```bash
# Wildcard with Cloudflare
sudo certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
  -d yourdomain.com -d "*.yourdomain.com"

# Wildcard with DigitalOcean
sudo certbot certonly --dns-digitalocean \
  --dns-digitalocean-credentials /etc/letsencrypt/digitalocean/credentials.ini \
  -d yourdomain.com -d "*.yourdomain.com"

# Wildcard manual
sudo certbot certonly --manual --preferred-challenges dns \
  -d yourdomain.com -d "*.yourdomain.com"

# Multi-domain SAN
sudo certbot --nginx -d domain1.com -d domain2.com -d domain3.com

# Expand existing certificate
sudo certbot --nginx --expand -d yourdomain.com -d newdomain.com
```

---

> **Next:** [SSL Troubleshooting](SSL-TROUBLESHOOTING.md) | [Back to SSL Setup](SSL-SETUP-GUIDE.md)
