# VPS Quick Reference Cheatsheet

## 🚀 Initial Setup (One-Time)
```bash
# 1. Upload and run setup script
scp vps-setup.sh root@YOUR_VPS_IP:/root/
ssh root@YOUR_VPS_IP
chmod +x vps-setup.sh
./vps-setup.sh

# 2. Test new user access
ssh deploy@YOUR_VPS_IP
```

## 📦 Deploy New App
```bash
# On VPS
cd /var/www/apps
git clone YOUR_REPO myapp
cd myapp
npm install
npm run build

# Create ecosystem.config.js
pm2 start ecosystem.config.js
pm2 save

# Configure Nginx
sudo nano /etc/nginx/sites-available/myapp
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Get SSL
sudo certbot --nginx -d yourdomain.com
```

## 🔄 Update Existing App
```bash
cd /var/www/apps/myapp
git pull origin main
npm install
npm run build
pm2 restart myapp
```

## 📊 PM2 Commands
```bash
pm2 list                 # List all apps
pm2 start app.js         # Start app
pm2 restart myapp        # Restart specific app
pm2 restart all          # Restart all apps
pm2 stop myapp           # Stop app
pm2 delete myapp         # Remove app
pm2 logs                 # All logs
pm2 logs myapp           # Specific app logs
pm2 logs myapp --lines 100  # Last 100 lines
pm2 flush                # Clear all logs
pm2 monit                # Monitor resources
pm2 save                 # Save current process list
pm2 resurrect            # Restore saved processes
pm2 startup              # Generate startup script
```

## 🌐 Nginx Commands
```bash
sudo nginx -t                      # Test config
sudo systemctl status nginx        # Check status
sudo systemctl start nginx         # Start nginx
sudo systemctl stop nginx          # Stop nginx
sudo systemctl restart nginx       # Restart nginx
sudo systemctl reload nginx        # Reload config (no downtime)

# Config files
/etc/nginx/nginx.conf              # Main config
/etc/nginx/sites-available/        # Available sites
/etc/nginx/sites-enabled/          # Enabled sites

# Logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## 🔒 SSL / Certbot
```bash
# Install SSL for domain
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Renew all certificates
sudo certbot renew

# Test renewal (dry run)
sudo certbot renew --dry-run

# List certificates
sudo certbot certificates

# Delete certificate
sudo certbot delete --cert-name yourdomain.com
```

> 📖 **Full SSL Guides:**
> - [ssl/SSL-SETUP-GUIDE.md](ssl/SSL-SETUP-GUIDE.md) — Complete setup walkthrough
> - [ssl/SSL-WILDCARD-AND-MULTI-DOMAIN.md](ssl/SSL-WILDCARD-AND-MULTI-DOMAIN.md) — Wildcard & multi-domain certs
> - [ssl/SSL-TROUBLESHOOTING.md](ssl/SSL-TROUBLESHOOTING.md) — Fix common SSL issues

## 🔥 Firewall (UFW)
```bash
sudo ufw status                    # Check status
sudo ufw enable                    # Enable firewall
sudo ufw disable                   # Disable firewall
sudo ufw allow 22                  # Allow SSH
sudo ufw allow 80                  # Allow HTTP
sudo ufw allow 443                 # Allow HTTPS
sudo ufw allow 3000                # Allow port 3000
sudo ufw delete allow 3000         # Remove rule
sudo ufw status numbered           # List rules with numbers
sudo ufw delete 2                  # Delete rule #2
sudo ufw reset                     # Reset all rules
```

## 💾 MySQL Commands
```bash
# Login as root
sudo mysql -u root -p

# Inside MySQL:
SHOW DATABASES;
CREATE DATABASE mydb;
USE mydb;
SHOW TABLES;
DROP DATABASE mydb;

# Create user
CREATE USER 'username'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON dbname.* TO 'username'@'localhost';
FLUSH PRIVILEGES;

# Backup database
mysqldump -u root -p dbname > backup.sql

# Restore database
mysql -u root -p dbname < backup.sql

# Check MySQL status
sudo systemctl status mysql
sudo systemctl restart mysql
```

## 📝 System Logs
```bash
# Application logs
pm2 logs myapp

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# System logs
sudo journalctl -u nginx           # Nginx system logs
sudo journalctl -u mysql           # MySQL system logs
sudo journalctl -xe                # Recent system errors
sudo journalctl -f                 # Follow system logs

# Auth logs (login attempts)
sudo tail -f /var/log/auth.log

# Fail2Ban logs
sudo tail -f /var/log/fail2ban.log
```

## 🔍 Monitoring & Diagnostics
```bash
# System resources
htop                               # Interactive process viewer
top                                # Process viewer
free -h                            # Memory usage
df -h                              # Disk usage
du -sh /var/www/*                  # Directory sizes
uptime                             # System uptime

# Network
netstat -tulpn                     # All listening ports
netstat -tulpn | grep :3000        # Check if port 3000 is open
ss -tulpn                          # Modern alternative to netstat
curl localhost:3000                # Test local connection

# Processes
ps aux | grep node                 # Find Node processes
ps aux | grep nginx                # Find Nginx processes
kill -9 PID                        # Force kill process

# Check service status
sudo systemctl status nginx
sudo systemctl status mysql
sudo systemctl status fail2ban
```

## 👤 User Management
```bash
# Add user
sudo adduser username
sudo usermod -aG sudo username     # Add to sudo group

# Delete user
sudo deluser username
sudo deluser --remove-home username  # Also remove home directory

# Change password
sudo passwd username

# Switch user
su - username

# List all users
cat /etc/passwd
```

## 📁 File Operations
```bash
# Permissions
sudo chown user:group file         # Change owner
sudo chown -R user:group dir/      # Recursive
sudo chmod 755 file                # Change permissions
sudo chmod +x script.sh            # Make executable

# Find files
find /var/www -name "*.log"        # Find by name
find /var/www -type f -size +100M  # Files > 100MB
find /var/www -mtime -7            # Modified in last 7 days

# Disk cleanup
sudo apt autoremove                # Remove unused packages
sudo apt clean                     # Clean package cache
pm2 flush                          # Clear PM2 logs
```

## 🔄 Updates
```bash
# Update packages
sudo apt update                    # Update package lists
sudo apt upgrade                   # Upgrade packages
sudo apt dist-upgrade              # Distribution upgrade
sudo apt autoremove                # Remove unused packages

# Update Node.js
sudo npm install -g n              # Install version manager
sudo n stable                      # Install stable Node

# Update npm
sudo npm install -g npm@latest

# Update PM2
sudo npm install -g pm2@latest
pm2 update                         # Update PM2 daemon
```

## 🔐 SSH
```bash
# Generate SSH key (local machine)
ssh-keygen -t rsa -b 4096

# Copy SSH key to server (local machine)
ssh-copy-id user@server

# Connect
ssh user@server
ssh -p 2222 user@server            # Custom port

# SSH config (~/.ssh/config on local machine)
Host myserver
    HostName 123.45.67.89
    User deploy
    Port 22
    IdentityFile ~/.ssh/id_rsa

# Then connect with:
ssh myserver

# Disable password auth (on server)
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart sshd
```

## 🐛 Common Issues & Fixes

### App Won't Start
```bash
pm2 logs myapp                     # Check logs
pm2 restart myapp --update-env     # Restart with env
cd /var/www/apps/myapp && npm install  # Reinstall deps
```

### 502 Bad Gateway
```bash
pm2 status                         # Check if app running
sudo nginx -t                      # Test nginx config
sudo systemctl restart nginx       # Restart nginx
```

### Port Already in Use
```bash
sudo lsof -i :3000                 # Find process on port
kill -9 PID                        # Kill the process
pm2 restart myapp                  # Restart app
```

### High Memory Usage
```bash
free -h                            # Check memory
pm2 monit                          # Monitor PM2 apps
pm2 restart myapp                  # Restart app
```

### SSL Certificate Issues
```bash
sudo certbot renew                 # Renew certificate
sudo nginx -t && sudo systemctl reload nginx
```

### Can't Connect via SSH
```bash
# From VPS console (DigitalOcean/Linode panel):
sudo systemctl status sshd         # Check SSH status
sudo systemctl start sshd          # Start SSH
sudo ufw allow 22                  # Allow SSH in firewall
```

## 📋 Environment Variables
```bash
# Set in ecosystem.config.js
env: {
  NODE_ENV: 'production',
  DATABASE_URL: 'mysql://...',
  API_KEY: 'abc123'
}

# Or use .env file
nano /var/www/apps/myapp/.env
# Then restart:
pm2 restart myapp
```

## 🔄 GitHub Actions Secrets
```
VPS_HOST         = 123.45.67.89
VPS_USERNAME     = deploy
VPS_SSH_KEY      = (private key from ~/.ssh/github_deploy_key)
```

## ⚡ Quick Deploy Script
```bash
#!/bin/bash
cd /var/www/apps/myapp
git pull origin main
npm install
npm run build
pm2 restart myapp
pm2 save
echo "✅ Deployed!"
```

Save as `deploy.sh`, make executable: `chmod +x deploy.sh`

## 📊 Useful Aliases
Add to `~/.bashrc`:
```bash
alias ll='ls -lah'
alias pm2log='pm2 logs --lines 100'
alias nginxreload='sudo nginx -t && sudo systemctl reload nginx'
alias update='sudo apt update && sudo apt upgrade -y'
```

Then: `source ~/.bashrc`

## 🎯 Production Checklist
- [ ] SSH password auth disabled
- [ ] Firewall enabled (UFW)
- [ ] Fail2Ban running
- [ ] SSL certificate installed
- [ ] PM2 startup configured
- [ ] Environment variables set
- [ ] Database backed up
- [ ] Nginx configured
- [ ] DNS pointing to VPS
- [ ] Monitoring setup

## 📞 Emergency Commands
```bash
# System is unresponsive
sudo reboot

# App crashed and won't restart
pm2 delete myapp
pm2 start ecosystem.config.js
pm2 save

# Nginx won't start
sudo nginx -t                      # Find config error
sudo systemctl status nginx        # Check error details

# Out of disk space
du -sh /* | sort -h                # Find large directories
sudo apt clean                     # Clean package cache
pm2 flush                          # Clear logs
```

## 🔗 Helpful Resources
- PM2 Docs: https://pm2.keymetrics.io/
- Nginx Docs: https://nginx.org/en/docs/
- Certbot: https://certbot.eff.org/
- UFW Guide: https://help.ubuntu.com/community/UFW

---

**💡 Pro Tip:** Bookmark this file! Keep it handy for quick reference.
