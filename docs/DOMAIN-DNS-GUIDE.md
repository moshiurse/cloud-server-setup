# Domain & DNS Setup Guide

> **Goal:** Point your domain name to your VPS so visitors can reach your site by typing `yourdomain.com` instead of an IP address like `203.0.113.50`.

---

## Table of Contents

1. [DNS Basics Explained](#1-dns-basics-explained)
2. [DNS Record Types](#2-dns-record-types)
3. [Step-by-Step: Point Domain to VPS](#3-step-by-step-point-domain-to-vps)
4. [Common DNS Configurations](#4-common-dns-configurations)
5. [Cloudflare Setup (Recommended)](#5-cloudflare-setup-recommended)
6. [DNS Management at Popular Registrars](#6-dns-management-at-popular-registrars)
7. [Troubleshooting DNS](#7-troubleshooting-dns)
8. [DNS Checklist](#8-dns-checklist--pre-ssl-verification)

---

## 1. DNS Basics Explained

### What Is DNS?

DNS (Domain Name System) is the phone book of the internet. It translates human-readable domain names like `example.com` into machine-readable IP addresses like `203.0.113.50`.

Without DNS, you would need to memorize IP addresses for every website you visit.

### How DNS Resolution Works

When you type `example.com` in your browser, here's what happens:

```
You type example.com
        │
        ▼
┌──────────────────┐
│   Your Browser   │  Checks its own cache first
└────────┬─────────┘
         │ Not cached
         ▼
┌──────────────────┐
│  DNS Resolver    │  Your ISP's or a public resolver (e.g., 8.8.8.8)
│  (Recursive)     │  Checks its cache — if found, returns immediately
└────────┬─────────┘
         │ Not cached
         ▼
┌──────────────────┐
│  Root Server     │  "I don't know example.com, but ask the .com server"
│  (.)             │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  TLD Server      │  "I don't know example.com, but ask ns1.registrar.com"
│  (.com)          │
└────────┬─────────┘
         │
         ▼
┌──────────────────────┐
│  Authoritative       │  "example.com is at 203.0.113.50" ✓
│  Nameserver          │
└──────────┬───────────┘
           │
           ▼
    Response flows back
    through the chain to
    your browser
```

**In short:** Browser → Resolver → Root → TLD → Authoritative Nameserver → IP returned.

### DNS Propagation

When you create or change a DNS record, it doesn't update everywhere instantly. This delay is called **DNS propagation**.

**Why does it take time?**
- DNS resolvers around the world cache records for a period defined by the **TTL** (Time To Live).
- Until the cached record expires, some resolvers may still return the old value.
- Typical propagation time: **5 minutes to 48 hours** (usually under 1 hour for most users).

**How to check propagation:**
```bash
# Check from your machine
dig example.com +short

# Check from a specific DNS server (Google's)
dig @8.8.8.8 example.com +short

# Check from Cloudflare's DNS
dig @1.1.1.1 example.com +short
```

**Online propagation checkers:**
- [whatsmydns.net](https://www.whatsmydns.net/) — see results from DNS servers worldwide
- [dnschecker.org](https://dnschecker.org/) — similar global check

---

## 2. DNS Record Types

### Overview Table

| Record Type | Purpose | Example Value | When to Use |
|-------------|---------|---------------|-------------|
| **A** | Points domain to an IPv4 address | `203.0.113.50` | Always — this is how your domain finds your VPS |
| **AAAA** | Points domain to an IPv6 address | `2001:db8::1` | If your VPS has an IPv6 address |
| **CNAME** | Alias one name to another | `www` → `example.com` | For `www` subdomain or other aliases |
| **MX** | Mail server routing | `mail.example.com` (priority: 10) | If you send/receive email on your domain |
| **TXT** | Text data (verification, email auth) | `v=spf1 include:_spf.google.com ~all` | Domain verification, SPF, DKIM, DMARC |
| **NS** | Delegates domain to nameservers | `ns1.cloudflare.com` | Set automatically by registrar; change if using Cloudflare/other DNS |

### A Record (IPv4) — The Most Important Record

The **A record** maps your domain to your VPS IP address. This is the one record you absolutely must set.

```
Type: A
Name: @              (or leave blank — means the root domain)
Value: 203.0.113.50  (your VPS IP address)
TTL: 3600            (1 hour, or "Automatic")
```

> **`@`** is shorthand for your root domain (e.g., `example.com`).

### AAAA Record (IPv6)

Same as the A record, but for IPv6 addresses.

```
Type: AAAA
Name: @
Value: 2001:db8::1
TTL: 3600
```

> Only add this if your VPS provider assigned you an IPv6 address. You can check with `ip -6 addr` on your server.

### CNAME Record (Aliases)

A **CNAME record** points one domain name to another. Most commonly used to make `www.example.com` point to `example.com`.

```
Type: CNAME
Name: www
Value: example.com
TTL: 3600
```

> **Important:** You cannot have a CNAME on the root domain (`@`). CNAMEs are only for subdomains.

### MX Record (Email Routing)

**MX records** tell the internet where to deliver email for your domain.

```
Type: MX
Name: @
Value: mail.example.com
Priority: 10
TTL: 3600
```

If you use a hosted email service, they'll give you the MX values:

| Email Provider | MX Record Value | Priority |
|----------------|-----------------|----------|
| Google Workspace | `aspmx.l.google.com` | 1 |
| Google Workspace | `alt1.aspmx.l.google.com` | 5 |
| Zoho Mail | `mx.zoho.com` | 10 |
| Zoho Mail | `mx2.zoho.com` | 20 |
| ProtonMail | `mail.protonmail.ch` | 10 |
| ProtonMail | `mailsec.protonmail.ch` | 20 |

### TXT Record (Verification & Email Security)

TXT records store arbitrary text. Common uses:

**Domain verification** (Google, Let's Encrypt, etc.):
```
Type: TXT
Name: @
Value: google-site-verification=abc123xyz
```

**SPF record** (who can send email as your domain):
```
Type: TXT
Name: @
Value: v=spf1 ip4:203.0.113.50 ~all
```

**DKIM record** (email signature verification):
```
Type: TXT
Name: default._domainkey
Value: v=DKIM1; k=rsa; p=MIGfMA0GCSq...  (provided by your email service)
```

**DMARC record** (email authentication policy):
```
Type: TXT
Name: _dmarc
Value: v=DMARC1; p=quarantine; rua=mailto:admin@example.com
```

### NS Record (Nameservers)

NS records specify which nameservers are authoritative for your domain. You typically don't create these manually — they're set when you register the domain or switch to a DNS provider like Cloudflare.

```
Type: NS
Name: @
Value: ns1.cloudflare.com
```

### Complete Example DNS Setup

Here's what a typical DNS configuration looks like for `example.com` hosted on a VPS at `203.0.113.50`:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `@` | `203.0.113.50` | 3600 |
| AAAA | `@` | `2001:db8::1` | 3600 |
| CNAME | `www` | `example.com` | 3600 |
| MX | `@` | `mail.example.com` (priority 10) | 3600 |
| TXT | `@` | `v=spf1 ip4:203.0.113.50 ~all` | 3600 |

---

## 3. Step-by-Step: Point Domain to VPS

### Step 1: Buy a Domain

Purchase a domain from any registrar. Recommended options:

| Registrar | Notes |
|-----------|-------|
| [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/) | At-cost pricing, integrated DNS — best overall value |
| [Namecheap](https://www.namecheap.com/) | Affordable, good UI, free WhoisGuard |
| [Google Domains](https://domains.google/) | Simple, clean interface (now via Squarespace) |
| [GoDaddy](https://www.godaddy.com/) | Widely used — watch out for upsells |

> **Tip:** Cloudflare Registrar sells domains at wholesale cost with no markup, and DNS management is built in.

### Step 2: Find Your VPS IP Address

SSH into your VPS and run:

```bash
# Method 1: Check your public IPv4 address
curl -4 ifconfig.me

# Method 2: Alternative
ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1

# Method 3: Check IPv6 (if available)
curl -6 ifconfig.me
```

You can also find your IP in your VPS provider's dashboard (DigitalOcean, Linode, Vultr, AWS, etc.).

> **Write down your IP.** You'll need it: e.g., `203.0.113.50`

### Step 3: Add an A Record at Your Registrar

Log in to your domain registrar and navigate to the DNS settings for your domain.

Add the following record:

```
Type:  A
Name:  @           (this means the root domain — example.com)
Value: 203.0.113.50  (replace with YOUR VPS IP)
TTL:   Automatic    (or 3600 for 1 hour)
```

### Step 4: Add a CNAME for www

So that `www.example.com` also works:

```
Type:  CNAME
Name:  www
Value: example.com   (points www to your root domain)
TTL:   Automatic
```

> **Alternative:** Instead of a CNAME, you can add a second A record for `www` pointing to the same IP. Both approaches work.

### Step 5: Wait for DNS Propagation

After saving, DNS changes need time to propagate globally.

- **Best case:** 5–15 minutes
- **Typical:** Under 1 hour
- **Worst case:** Up to 48 hours (rare)

If you just registered the domain, initial propagation is usually fast. Changing existing records depends on the old TTL value.

### Step 6: Verify with dig/nslookup

```bash
# Verify A record
dig example.com +short
# Expected output: 203.0.113.50

# Verify www CNAME
dig www.example.com +short
# Expected output:
# example.com.         (the CNAME target)
# 203.0.113.50         (resolved IP)

# Using nslookup (alternative)
nslookup example.com
# Expected: Address: 203.0.113.50

# Query a specific DNS server to bypass local cache
dig @8.8.8.8 example.com +short

# Verbose output with full details
dig example.com ANY +noall +answer
```

**Test from your browser:**
1. Open `http://example.com` — you should see your server's default page or your app.
2. Open `http://www.example.com` — should work too.

> If you haven't set up a web server yet, you'll get a connection refused or default page. That's fine — it means DNS is working if the IP resolves correctly.

---

## 4. Common DNS Configurations

### Single App: Root Domain + www

The most basic setup — one website accessible at both `example.com` and `www.example.com`:

| Type | Name | Value |
|------|------|-------|
| A | `@` | `203.0.113.50` |
| CNAME | `www` | `example.com` |

Your Nginx config would handle both:
```nginx
server {
    server_name example.com www.example.com;
    # ... rest of config
}
```

### Subdomains for Different Services

Run multiple services on the same VPS using subdomains:

| Type | Name | Value | Service |
|------|------|-------|---------|
| A | `@` | `203.0.113.50` | Main website |
| CNAME | `www` | `example.com` | Main website (alias) |
| A | `api` | `203.0.113.50` | Backend API |
| A | `admin` | `203.0.113.50` | Admin panel |
| A | `staging` | `203.0.113.50` | Staging environment |
| A | `grafana` | `203.0.113.50` | Monitoring dashboard |

Each subdomain gets its own Nginx server block:

```nginx
# /etc/nginx/sites-available/api.example.com
server {
    server_name api.example.com;
    location / {
        proxy_pass http://localhost:3001;
    }
}

# /etc/nginx/sites-available/admin.example.com
server {
    server_name admin.example.com;
    location / {
        proxy_pass http://localhost:3002;
    }
}
```

> **Key concept:** All subdomains point to the same VPS IP. Nginx uses the `server_name` to route each request to the correct application.

### Multiple Domains on the Same VPS

You can host completely different domains on one VPS:

| Domain | Type | Name | Value |
|--------|------|------|-------|
| `siteone.com` | A | `@` | `203.0.113.50` |
| `siteone.com` | CNAME | `www` | `siteone.com` |
| `sitetwo.com` | A | `@` | `203.0.113.50` |
| `sitetwo.com` | CNAME | `www` | `sitetwo.com` |

Each domain gets its own Nginx server block, and Certbot can issue separate SSL certificates for each.

### Email DNS Records

If you send email from your domain (even just transactional emails), set these up to avoid being flagged as spam:

**Minimum email DNS records:**

| Type | Name | Value | Purpose |
|------|------|-------|---------|
| MX | `@` | Your mail server or provider's MX | Where to deliver incoming email |
| TXT | `@` | `v=spf1 ip4:203.0.113.50 include:_spf.google.com ~all` | Who can send email as you |
| TXT | `default._domainkey` | `v=DKIM1; k=rsa; p=...` | Email signature key |
| TXT | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:admin@example.com` | Authentication policy |

**SPF explained in plain English:**
```
v=spf1                          → "This is an SPF record"
ip4:203.0.113.50                → "My VPS can send email for this domain"
include:_spf.google.com         → "Google Workspace can also send for me"
~all                            → "Soft-fail anything else" (mark as suspicious)
```

> **Tip:** If you're not sending email from your domain, add this SPF to prevent spoofing:
> ```
> v=spf1 -all
> ```
> This tells the world "nobody is authorized to send email from this domain."

---

## 5. Cloudflare Setup (Recommended)

### Why Use Cloudflare?

Cloudflare's free tier provides:

- ✅ **Free DNS hosting** — fast, reliable, global anycast network
- ✅ **Free CDN** — caches your static content at edge locations worldwide
- ✅ **Free DDoS protection** — absorbs malicious traffic before it reaches your VPS
- ✅ **Free SSL certificates** — between visitors and Cloudflare
- ✅ **Easy DNS management** — clean interface with fast propagation
- ✅ **Analytics** — basic traffic and threat analytics

### Step 1: Sign Up and Add Your Domain

1. Go to [cloudflare.com](https://www.cloudflare.com/) and create a free account.
2. Click **"Add a site"** and enter your domain (e.g., `example.com`).
3. Select the **Free plan**.
4. Cloudflare will scan your existing DNS records and import them.
5. **Review the imported records** — make sure your A record and CNAME are correct.

### Step 2: Change Nameservers at Your Registrar

Cloudflare will give you two nameservers, for example:

```
ns1.cloudflare.com
ns2.cloudflare.com
```

Go to your domain registrar and replace the existing nameservers with Cloudflare's.

> **Where to find nameserver settings:**
> - **Namecheap:** Domain List → Manage → Nameservers → Custom DNS
> - **GoDaddy:** My Products → DNS → Nameservers → Change
> - **Google Domains:** DNS → Custom name servers

**After changing nameservers:**
- Go back to Cloudflare and click **"Check nameservers"**
- Wait 5–30 minutes (can take up to 24 hours in rare cases)
- Cloudflare will email you when it's active

### Step 3: Configure DNS Records in Cloudflare

In Cloudflare dashboard → **DNS** → **Records**:

| Type | Name | Content | Proxy Status |
|------|------|---------|--------------|
| A | `@` | `203.0.113.50` | Proxied (orange cloud) |
| CNAME | `www` | `example.com` | Proxied (orange cloud) |
| A | `api` | `203.0.113.50` | DNS only (grey cloud) |

> Records are added/edited directly in Cloudflare's DNS dashboard once it manages your domain.

### Cloudflare SSL Modes Explained

Navigate to **SSL/TLS** → **Overview** in the Cloudflare dashboard.

```
                    SSL MODE: OFF
┌─────────┐  HTTP   ┌────────────┐  HTTP   ┌─────────┐
│ Visitor │ ──────► │ Cloudflare │ ──────► │   VPS   │
└─────────┘         └────────────┘         └─────────┘
  ⚠️ No encryption anywhere. Never use this.


                    SSL MODE: FLEXIBLE
┌─────────┐  HTTPS  ┌────────────┐  HTTP   ┌─────────┐
│ Visitor │ ──────► │ Cloudflare │ ──────► │   VPS   │
└─────────┘  🔒     └────────────┘  ⚠️     └─────────┘
  Encrypted to Cloudflare, but NOT to your server.
  ⚠️ Can cause redirect loops with Let's Encrypt.


                    SSL MODE: FULL
┌─────────┐  HTTPS  ┌────────────┐  HTTPS  ┌─────────┐
│ Visitor │ ──────► │ Cloudflare │ ──────► │   VPS   │
└─────────┘  🔒     └────────────┘  🔒     └─────────┘
  Encrypted on both sides, but Cloudflare does NOT
  verify your server's certificate. Accepts self-signed.


                    SSL MODE: FULL (STRICT)  ✅ RECOMMENDED
┌─────────┐  HTTPS  ┌────────────┐  HTTPS  ┌─────────┐
│ Visitor │ ──────► │ Cloudflare │ ──────► │   VPS   │
└─────────┘  🔒     └────────────┘  🔒✓    └─────────┘
  Encrypted on both sides. Cloudflare VERIFIES your
  server's certificate is valid (Let's Encrypt or
  Cloudflare Origin CA).
```

> ### ⚠️ IMPORTANT: Always Use "Full (Strict)" with Let's Encrypt
>
> If you have Let's Encrypt certificates on your VPS (set up via Certbot), **always set Cloudflare SSL to "Full (Strict)"**.
>
> Using "Flexible" mode with Let's Encrypt **will cause infinite redirect loops** because:
> 1. Cloudflare sends HTTP to your server
> 2. Your server redirects HTTP → HTTPS
> 3. Cloudflare sends HTTP again → loop
>
> **Set it:** Cloudflare Dashboard → SSL/TLS → Overview → **Full (Strict)**

### Proxy (Orange Cloud) vs DNS Only (Grey Cloud)

Every DNS record in Cloudflare has a proxy toggle:

| | Proxied (Orange Cloud 🟠) | DNS Only (Grey Cloud ⚫) |
|---|---|---|
| **Traffic flows through** | Cloudflare's network | Directly to your VPS |
| **Your VPS IP** | Hidden from public | Exposed to public |
| **CDN caching** | ✅ Yes | ❌ No |
| **DDoS protection** | ✅ Yes | ❌ No |
| **Cloudflare SSL** | ✅ Yes | ❌ No (use your own) |
| **WebSocket support** | ✅ Yes | ✅ Yes |
| **Non-HTTP ports** | ❌ Limited | ✅ All ports work |

**When to use Proxied (orange cloud):**
- Web applications (HTTP/HTTPS traffic)
- Static websites
- APIs that use standard HTTP ports (80/443)
- Any service where you want CDN + DDoS protection

**When to use DNS Only (grey cloud):**
- SSH access (you can also use Cloudflare Tunnel for SSH)
- Mail servers (MX records must always be DNS only)
- Game servers or apps that use non-standard ports
- Services that need direct TCP/UDP connections
- When you need your real VPS IP to be reachable

> **Tip:** MX records are always DNS only. Cloudflare will not proxy email traffic.

### Cloudflare Page Rules (Basics)

Page Rules let you customize Cloudflare behavior for specific URLs. Free plan includes **3 page rules**.

**Common page rules:**

**1. Force HTTPS everywhere:**
```
URL: http://*example.com/*
Setting: Always Use HTTPS
```

**2. Redirect www to non-www (or vice versa):**
```
URL: www.example.com/*
Setting: Forwarding URL (301)
Destination: https://example.com/$1
```

**3. Bypass cache for admin area:**
```
URL: example.com/admin/*
Setting: Cache Level → Bypass
```

> **Note:** Cloudflare now also offers **Redirect Rules** and **Transform Rules** which are more powerful and don't count toward the 3-rule limit.

### Cloudflare with Nginx — Passing Real Visitor IPs

When Cloudflare proxies your traffic, Nginx sees Cloudflare's IP addresses instead of your visitors' real IPs. This affects your access logs and any IP-based logic.

**Fix: Use Nginx's `real_ip` module.**

Create a Cloudflare real IP configuration file:

```nginx
# /etc/nginx/conf.d/cloudflare-real-ip.conf

# Cloudflare IPv4 ranges
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 131.0.72.0/22;

# Cloudflare IPv6 ranges
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2a06:98c0::/29;
set_real_ip_from 2c0f:f248::/32;

# Use the CF-Connecting-IP header
real_ip_header CF-Connecting-IP;
```

Then test and reload Nginx:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

> **Keep this updated!** Cloudflare's IP ranges can change. Check the latest at:
> [cloudflare.com/ips](https://www.cloudflare.com/ips/)

You can automate updates with a cron script:
```bash
#!/bin/bash
# /opt/scripts/update-cloudflare-ips.sh

CF_CONF="/etc/nginx/conf.d/cloudflare-real-ip.conf"

echo "# Cloudflare Real IP — auto-updated $(date)" > "$CF_CONF"
echo "" >> "$CF_CONF"

for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
    echo "set_real_ip_from $ip;" >> "$CF_CONF"
done

for ip in $(curl -s https://www.cloudflare.com/ips-v6); do
    echo "set_real_ip_from $ip;" >> "$CF_CONF"
done

echo "" >> "$CF_CONF"
echo "real_ip_header CF-Connecting-IP;" >> "$CF_CONF"

nginx -t && systemctl reload nginx
```

---

## 6. DNS Management at Popular Registrars

### Namecheap

1. Log in → **Domain List** → click **Manage** on your domain.
2. Go to the **Advanced DNS** tab.
3. Under **Host Records**, click **Add New Record**.
4. Add your records:
   - **A Record:** Host = `@`, Value = your VPS IP, TTL = Automatic
   - **CNAME:** Host = `www`, Value = `example.com.`, TTL = Automatic
5. Click the ✓ to save each record.
6. Delete any default parking records (they look like `CNAME → parkingpage.namecheap.com`).

> **To use Cloudflare:** Go to the **Domain** tab → Nameservers → select **Custom DNS** → enter Cloudflare's nameservers.

### GoDaddy

1. Log in → **My Products** → click **DNS** next to your domain.
2. Under **DNS Records**, click **Add**.
3. Add your records:
   - **Type:** A, **Name:** `@`, **Value:** your VPS IP, **TTL:** 1 Hour
   - **Type:** CNAME, **Name:** `www`, **Value:** `example.com`, **TTL:** 1 Hour
4. Click **Save**.
5. Remove any default parked/forwarding records.

> **To use Cloudflare:** Scroll to Nameservers → **Change** → enter Cloudflare's nameservers.

### DigitalOcean DNS

If your VPS is on DigitalOcean, you can use their DNS:

1. In the **DigitalOcean dashboard** → **Networking** → **Domains**.
2. Enter your domain and click **Add Domain**.
3. Add records:
   - **A Record:** `@` → select your Droplet (or enter IP)
   - **CNAME:** `www` → `@`
4. At your registrar, set nameservers to:
   ```
   ns1.digitalocean.com
   ns2.digitalocean.com
   ns3.digitalocean.com
   ```

### AWS Route 53

1. Go to **Route 53** → **Hosted zones** → **Create hosted zone**.
2. Enter your domain name → **Create**.
3. Add records:
   - Click **Create record** → **Simple routing**
   - **Record name:** leave blank (root) or enter subdomain
   - **Record type:** A
   - **Value:** your VPS IP
   - **TTL:** 300
4. Route 53 gives you 4 nameservers (e.g., `ns-123.awsdns-45.com`).
5. Update your registrar's nameservers to these.

> **Note:** Route 53 costs $0.50/month per hosted zone + small per-query fees. For most people, Cloudflare's free DNS is a better option.

---

## 7. Troubleshooting DNS

### Domain Not Resolving

**Symptoms:** Browser shows "This site can't be reached" or "DNS_PROBE_FINISHED_NXDOMAIN".

**Steps:**

```bash
# 1. Check if the A record exists
dig example.com +short
# If empty → A record is missing or hasn't propagated

# 2. Query a public DNS to bypass local cache
dig @8.8.8.8 example.com +short

# 3. Check nameservers
dig example.com NS +short
# Are they what you expect? (your registrar's or Cloudflare's?)

# 4. Flush your local DNS cache
# macOS:
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
# Linux:
sudo systemd-resolve --flush-caches
# Windows:
ipconfig /flushdns
```

**Common causes:**
- A record not created yet
- Nameservers not updated at registrar
- Domain registration not fully activated (new domains can take a few hours)
- Typo in the domain name in DNS settings

### Wrong IP Address Resolving

```bash
# Check what IP is resolving
dig example.com +short
# If it shows an old or wrong IP:

# Check the TTL of the current record
dig example.com +noall +answer
# Look at the TTL column — that's how many seconds until caches refresh

# Force check at authoritative nameserver
dig example.com @$(dig example.com NS +short | head -1) +short
```

**If authoritative shows the correct IP but other resolvers don't:** Just wait — it's propagation. The old TTL needs to expire.

### Propagation Seems Stuck

1. Check [whatsmydns.net](https://www.whatsmydns.net/) — are some regions resolving correctly?
2. If **no regions** show your IP after 1 hour:
   - Verify the record in your DNS provider's dashboard
   - Make sure you edited the correct domain (easy mistake with multiple domains)
   - Check that nameservers are correct: `dig example.com NS +short`
3. If **some regions** show your IP: This is normal propagation. Give it more time (up to 24–48 hours for nameserver changes).

### Mixed DNS/SSL Issues with Cloudflare

**Problem: Redirect loop (ERR_TOO_MANY_REDIRECTS)**

This almost always means Cloudflare SSL is set to "Flexible" but your server forces HTTPS.

**Fix:**
1. Cloudflare Dashboard → **SSL/TLS** → set to **Full (Strict)**
2. Make sure your server has a valid SSL certificate (Let's Encrypt)

**Problem: SSL certificate error (invalid certificate)**

If Cloudflare SSL is "Full (Strict)" but your origin cert is expired or missing:

```bash
# Check your certificate on the server
sudo certbot certificates
# Renew if expired
sudo certbot renew
```

**Problem: Mixed content warnings**

Your site loads over HTTPS but some resources (images, scripts) use HTTP URLs.

**Fix in Cloudflare:** SSL/TLS → Edge Certificates → enable **"Always Use HTTPS"** and **"Automatic HTTPS Rewrites"**

### Useful dig & nslookup Commands

```bash
# Basic A record lookup
dig example.com A +short

# Full answer with TTL
dig example.com +noall +answer

# Query specific DNS server
dig @8.8.8.8 example.com A +short

# Look up all record types
dig example.com ANY +noall +answer

# Check MX records
dig example.com MX +short

# Check TXT records (SPF, DKIM, etc.)
dig example.com TXT +short

# Check CNAME
dig www.example.com CNAME +short

# Check nameservers
dig example.com NS +short

# Trace the full resolution path
dig example.com +trace

# Using nslookup (if dig isn't available)
nslookup example.com
nslookup -type=MX example.com
nslookup -type=TXT example.com
nslookup example.com 8.8.8.8
```

### Online DNS Tools

| Tool | URL | Use Case |
|------|-----|----------|
| whatsmydns.net | [whatsmydns.net](https://www.whatsmydns.net/) | Global DNS propagation check |
| dnschecker.org | [dnschecker.org](https://dnschecker.org/) | Similar propagation check |
| MXToolbox | [mxtoolbox.com](https://mxtoolbox.com/) | Email DNS diagnostics (MX, SPF, DKIM) |
| SSL Labs | [ssllabs.com/ssltest](https://www.ssllabs.com/ssltest/) | Test SSL certificate setup |
| DNS Viz | [dnsviz.net](https://dnsviz.net/) | Visual DNS resolution and DNSSEC check |

---

## 8. DNS Checklist — Pre-SSL Verification

Before requesting SSL certificates with Let's Encrypt/Certbot, verify all of the following:

```
✅ Domain registered and active
✅ A record created: @ → your VPS IP
✅ CNAME created: www → your root domain (or second A record)
✅ Nameservers updated (if using Cloudflare or other DNS provider)
✅ DNS propagation complete — verified with:
      dig yourdomain.com +short  →  shows your VPS IP
      dig www.yourdomain.com +short  →  shows your VPS IP
✅ Nginx is running and serving your domain:
      sudo nginx -t && sudo systemctl status nginx
✅ Nginx server_name matches your domain:
      server_name yourdomain.com www.yourdomain.com;
✅ Port 80 is open on your firewall:
      sudo ufw status  →  80/tcp ALLOW
✅ If using Cloudflare proxy: SSL mode set to "Full (Strict)"
✅ If using Cloudflare proxy: Temporarily set to "DNS only" (grey cloud)
   for initial Certbot setup, then re-enable proxy after
```

> **Why disable Cloudflare proxy for Certbot?**
>
> Certbot's HTTP challenge needs to reach your server directly on port 80. If Cloudflare's proxy is active, the challenge may fail. After getting your certificate, re-enable the orange cloud.
>
> **Alternative:** Use Certbot's DNS challenge (`--preferred-challenges dns`) which works with Cloudflare proxy enabled. The Certbot Cloudflare plugin can automate this:
> ```bash
> sudo apt install python3-certbot-dns-cloudflare
> sudo certbot certonly --dns-cloudflare \
>   --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
>   -d example.com -d www.example.com
> ```

---

## Quick Reference

### Minimum DNS Setup (Copy-Paste)

Replace `203.0.113.50` with your VPS IP and `example.com` with your domain:

| Type | Name | Value |
|------|------|-------|
| A | `@` | `203.0.113.50` |
| CNAME | `www` | `example.com` |

### Verification Commands

```bash
# Check A record resolves to your IP
dig yourdomain.com +short

# Check www resolves
dig www.yourdomain.com +short

# Check from Google's DNS (bypass cache)
dig @8.8.8.8 yourdomain.com +short

# Check global propagation
# Visit: https://www.whatsmydns.net/
```

---

**Next Steps:** Once DNS is verified, proceed to [SSL setup with Let's Encrypt](./SSL-LETSENCRYPT-GUIDE.md) to secure your domain with HTTPS.
