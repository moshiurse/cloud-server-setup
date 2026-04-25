# VPS Deployment Kit for Next.js

Complete automation for deploying Next.js apps on a VPS with one script.

## 📦 What's Included

1. **vps-setup.sh** - Automated VPS setup script
2. **DEPLOYMENT-GUIDE.md** - Complete step-by-step guide
3. **CHEATSHEET.md** - Quick reference for common commands
4. **nginx/** - Nginx configuration templates (Next.js, PHP, Node.js, React.js)
5. **workflows/** - GitHub Actions CI/CD pipelines (React, Node.js, PHP, Laravel)
6. **.github-workflows-deploy.yml** - GitHub Actions CI/CD workflow (Next.js)
7. **ssl/** - SSL/TLS certificate guides (setup, wildcard, troubleshooting)

## 🚀 Quick Start

### Step 1: Buy VPS
- DigitalOcean, Linode, Vultr, or AWS Lightsail
- Ubuntu 22.04 LTS
- Minimum: 2GB RAM, 1 CPU ($10-12/month)

### Step 2: Edit Setup Script
```bash
nano vps-setup.sh
```

Change these variables:
```bash
NEW_USERNAME="deploy"              # Your username
YOUR_SSH_PUBLIC_KEY="ssh-rsa AAA..." # From ~/.ssh/id_rsa.pub
YOUR_DOMAIN="yourdomain.com"       # Your domain
YOUR_EMAIL="you@email.com"         # Your email
```

### Step 3: Upload & Run
```bash
# From your local machine
scp vps-setup.sh root@YOUR_VPS_IP:/root/

# SSH into VPS
ssh root@YOUR_VPS_IP

# Run setup
chmod +x vps-setup.sh
./vps-setup.sh
```

Wait 5-10 minutes for completion.

### Step 4: Deploy Your App
See **DEPLOYMENT-GUIDE.md** for detailed instructions.

## 📋 What Gets Installed

✅ **Security**
- SSH hardening (password auth disabled)
- UFW firewall
- Fail2Ban
- Automatic security updates

✅ **Web Server**
- Nginx
- SSL/TLS (Certbot)

✅ **Languages & Runtimes**
- Node.js 20
- PHP 8.2
- MySQL

✅ **Tools**
- PM2 (process manager)
- Git
- Composer

✅ **Monitoring**
- PM2 monitoring
- System logs

## 📚 Documentation

- **DEPLOYMENT-GUIDE.md** - Full deployment walkthrough
- **CHEATSHEET.md** - Quick command reference

## 🔧 Features

### Automated Setup
- Creates sudo user
- Disables root password login
- Configures firewall
- Installs all dependencies

### CI/CD Ready
- GitHub Actions workflow included
- Automated deployments on push
- Zero-downtime deployments

### Production Ready
- SSL certificates (Let's Encrypt)
- Nginx reverse proxy
- PM2 process management
- Automatic restarts

### Multiple Apps
- Host multiple apps on one VPS
- Subdomain support
- Port management

## 💰 Cost

- VPS: ~$10-12/month
- Domain: ~$10-15/year
- SSL: FREE (Let's Encrypt)
- **Total: ~$12/month**

## 🎯 What You Can Deploy

- Next.js applications
- React applications
- Node.js APIs
- Static websites
- PHP applications

## 📖 Usage Examples

### Deploy Single Next.js App
```bash
# See DEPLOYMENT-GUIDE.md → Part 2
cd /var/www/apps
git clone your-repo myapp
cd myapp
npm install && npm run build
pm2 start ecosystem.config.js
```

### Setup Nginx
```bash
# Use the appropriate nginx template from nginx/ folder
sudo cp nginx/nginx-nextjs.conf /etc/nginx/sites-available/myapp
# Edit domain and port
sudo nano /etc/nginx/sites-available/myapp
# Enable site
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Get SSL Certificate
```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

> 📖 **Full SSL Guide:** See [ssl/SSL-SETUP-GUIDE.md](ssl/SSL-SETUP-GUIDE.md) for detailed instructions, wildcard certs, and troubleshooting.

### Setup CI/CD
```bash
# Use .github-workflows-deploy.yml
# Add to your repo: .github/workflows/deploy.yml
# Configure GitHub secrets (see guide)
```

## 🆘 Troubleshooting

See **CHEATSHEET.md** → Common Issues & Fixes

Quick checks:
```bash
pm2 status              # Check if app is running
pm2 logs myapp          # View error logs
sudo nginx -t           # Test nginx config
sudo systemctl status nginx
```

## 🔐 Security Features

- ✅ SSH key-only authentication
- ✅ Firewall (UFW) enabled
- ✅ Fail2Ban brute-force protection
- ✅ SSL/TLS certificates
- ✅ Automatic security updates
- ✅ Non-root user for deployments

## 🚦 Post-Setup Checklist

After running vps-setup.sh:

- [ ] Test SSH access with new user: `ssh deploy@YOUR_VPS_IP`
- [ ] Save MySQL password from `/root/credentials.txt`
- [ ] Deploy your app (see DEPLOYMENT-GUIDE.md)
- [ ] Configure Nginx for your domain
- [ ] Get SSL certificate with Certbot
- [ ] Test your site: `https://yourdomain.com`
- [ ] Setup CI/CD (optional)
- [ ] Configure backups (see guide)

## 📞 Support

Common commands:
```bash
# Check all services
sudo systemctl status nginx
sudo systemctl status mysql
pm2 status

# View logs
pm2 logs
sudo tail -f /var/log/nginx/error.log

# Restart services
pm2 restart myapp
sudo systemctl restart nginx
```

## 🎓 Learning Resources

- Read **DEPLOYMENT-GUIDE.md** for complete walkthrough
- Use **CHEATSHEET.md** for quick reference
- Check PM2 docs: https://pm2.keymetrics.io/
- Check Nginx docs: https://nginx.org/en/docs/

## ⚡ Quick Commands

```bash
# Deploy update
cd /var/www/apps/myapp
git pull
npm install
npm run build
pm2 restart myapp

# Check logs
pm2 logs myapp --lines 100

# Monitor
pm2 monit
```

## 🎉 You're Ready!

Follow the **DEPLOYMENT-GUIDE.md** for complete instructions.

Quick summary:
1. ✅ Run vps-setup.sh (done)
2. 📦 Deploy your app
3. 🌐 Configure Nginx
4. 🔒 Get SSL certificate
5. 🚀 Your site is live!

---

Made with ❤️ for developers who want full control over their deployments.
