# Complete VPS Deployment Guide

## Part 1: Initial VPS Setup (One-Time)

### Step 1: Get Your VPS
- Buy VPS from: DigitalOcean, Linode, Vultr, AWS Lightsail, etc.
- Recommended specs: 2GB RAM, 1 CPU, 50GB SSD ($10-12/month)
- Choose Ubuntu 22.04 LTS

### Step 2: Connect to VPS
```bash
ssh root@YOUR_VPS_IP
```

### Step 3: Edit Setup Script Configuration
Before running the script, edit these variables:

```bash
nano vps-setup.sh
```

Change these lines at the top:
```bash
NEW_USERNAME="deploy"              # Your username
YOUR_SSH_PUBLIC_KEY="ssh-rsa AAA..." # Your public key from ~/.ssh/id_rsa.pub
YOUR_DOMAIN="yourdomain.com"       # Your domain
YOUR_EMAIL="you@email.com"         # Your email
```

To get your SSH public key on your local machine:
```bash
cat ~/.ssh/id_rsa.pub
# Copy the output and paste into the script
```

If you don't have an SSH key:
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
# Press Enter for all prompts
cat ~/.ssh/id_rsa.pub
```

### Step 4: Upload and Run Setup Script
```bash
# Upload the script (from your local machine)
scp vps-setup.sh root@YOUR_VPS_IP:/root/

# SSH into VPS
ssh root@YOUR_VPS_IP

# Make it executable
chmod +x /root/vps-setup.sh

# Run it
./vps-setup.sh
```

**The script will take 5-10 minutes to complete.**

### Step 5: Test New User Access
```bash
# From your local machine
ssh deploy@YOUR_VPS_IP

# You should be able to login without password (using SSH key)
```

**⚠️ IMPORTANT:** Test this BEFORE logging out of root! If it fails, you can still fix it.

### Step 6: Save Credentials
```bash
# On VPS, view saved MySQL password
sudo cat /root/credentials.txt
```

Save this information somewhere safe!

---

## Part 2: Deploy Your Next.js App

### Option A: Manual Deployment

#### 1. Create App Directory on VPS
```bash
ssh deploy@YOUR_VPS_IP

cd /var/www/apps
mkdir myapp
cd myapp

# Initialize git
git init
git remote add origin https://github.com/yourusername/yourrepo.git
git pull origin main
```

#### 2. Install Dependencies & Build
```bash
npm install
npm run build
```

#### 3. Create PM2 Ecosystem File
```bash
nano ecosystem.config.js
```

Paste:
```javascript
module.exports = {
  apps: [{
    name: 'myapp',
    script: 'node_modules/next/dist/bin/next',
    args: 'start',
    cwd: '/var/www/apps/myapp',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    time: true
  }]
}
```

#### 4. Start with PM2
```bash
mkdir logs
pm2 start ecosystem.config.js
pm2 save
pm2 startup  # Follow the instructions shown
```

#### 5. Configure Nginx
```bash
sudo nano /etc/nginx/sites-available/myapp
```

Paste the nginx config (from nginx/nginx-nextjs.conf file), replacing:
- `yourdomain.com` with your actual domain
- Port `3000` if your app uses different port

```bash
# Enable the site
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/

# Test nginx config
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

#### 6. Setup SSL
```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

Follow the prompts. Certbot will automatically configure HTTPS!

> 📖 **Full SSL Guide:** See [ssl/SSL-SETUP-GUIDE.md](ssl/SSL-SETUP-GUIDE.md) for detailed setup, wildcard certificates, and troubleshooting.
> For multi-domain or wildcard SSL, see [ssl/SSL-WILDCARD-AND-MULTI-DOMAIN.md](ssl/SSL-WILDCARD-AND-MULTI-DOMAIN.md).

#### 7. Test Your Site
Visit: `https://yourdomain.com`

Your Next.js app should be live! 🎉

---

### Option B: Automated CI/CD with GitHub Actions

#### 1. Setup GitHub Repository
```bash
# In your local project
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/yourusername/yourrepo.git
git push -u origin main
```

#### 2. Add GitHub Actions Workflow
Create `.github/workflows/deploy.yml` in your project:

Copy content from the `.github-workflows-deploy.yml` file provided.

#### 3. Generate Deploy Key on VPS
```bash
ssh deploy@YOUR_VPS_IP

# Generate new SSH key for deployment
ssh-keygen -t rsa -b 4096 -f ~/.ssh/github_deploy_key -N ""

# View the private key
cat ~/.ssh/github_deploy_key

# Copy this entire output
```

#### 4. Add GitHub Secrets
In your GitHub repository:
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add these secrets:

- `VPS_HOST`: Your VPS IP address (e.g., `123.45.67.89`)
- `VPS_USERNAME`: `deploy`
- `VPS_SSH_KEY`: Paste the private key from step 3

#### 5. Setup App on VPS (First Time)
```bash
ssh deploy@YOUR_VPS_IP

cd /var/www/apps
git clone https://github.com/yourusername/yourrepo.git myapp
cd myapp

npm install
npm run build

# Create ecosystem.config.js (same as manual method)
nano ecosystem.config.js

# Start with PM2
mkdir logs
pm2 start ecosystem.config.js
pm2 save
```

#### 6. Configure Nginx (Same as Manual)
Follow step 5 from Option A

#### 7. Test Deployment
```bash
# Make a change in your code locally
echo "# Test change" >> README.md
git add .
git commit -m "Test deployment"
git push origin main
```

Check GitHub Actions tab - you should see the workflow running!

---

## Part 3: Common Commands

### PM2 Commands
```bash
pm2 status              # Check app status
pm2 logs myapp          # View logs
pm2 restart myapp       # Restart app
pm2 stop myapp          # Stop app
pm2 delete myapp        # Remove app
pm2 monit              # Monitor resources
```

### Nginx Commands
```bash
sudo nginx -t                    # Test configuration
sudo systemctl reload nginx      # Reload nginx
sudo systemctl restart nginx     # Restart nginx
sudo systemctl status nginx      # Check status
```

### SSL Certificate Renewal
```bash
sudo certbot renew              # Renew all certificates
sudo certbot renew --dry-run    # Test renewal
```

Certbot auto-renews via cron, but you can test it.

### View Logs
```bash
# Application logs
pm2 logs myapp

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log

# System logs
sudo journalctl -u nginx -f
```

---

## Part 4: Environment Variables

### Add Environment Variables to PM2

Edit `ecosystem.config.js`:
```javascript
module.exports = {
  apps: [{
    name: 'myapp',
    script: 'node_modules/next/dist/bin/next',
    args: 'start',
    env: {
      NODE_ENV: 'production',
      PORT: 3000,
      DATABASE_URL: 'your-database-url',
      API_KEY: 'your-api-key',
      // Add more variables here
    }
  }]
}
```

Or use `.env` file:
```bash
# Create .env file
nano /var/www/apps/myapp/.env

# Add variables
DATABASE_URL=postgresql://...
API_KEY=abc123

# Restart app
pm2 restart myapp
```

---

## Part 5: Multiple Apps on Same VPS

You can host multiple Next.js apps:

### App 1: app1.yourdomain.com (Port 3000)
```bash
/var/www/apps/app1/
pm2 start ecosystem.config.js --name app1
```

Nginx config:
```nginx
server {
    server_name app1.yourdomain.com;
    location / {
        proxy_pass http://localhost:3000;
    }
}
```

### App 2: app2.yourdomain.com (Port 3001)
```bash
/var/www/apps/app2/
# Change PORT to 3001 in ecosystem.config.js
pm2 start ecosystem.config.js --name app2
```

Nginx config:
```nginx
server {
    server_name app2.yourdomain.com;
    location / {
        proxy_pass http://localhost:3001;
    }
}
```

---

## Part 6: Database Setup

### Create MySQL Database
```bash
sudo mysql -u root -p

# Inside MySQL:
CREATE DATABASE myapp_db;
CREATE USER 'myapp_user'@'localhost' IDENTIFIED BY 'strong_password';
GRANT ALL PRIVILEGES ON myapp_db.* TO 'myapp_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### Connection String
```
mysql://myapp_user:strong_password@localhost:3306/myapp_db
```

---

## Part 7: Troubleshooting

### App Not Starting
```bash
pm2 logs myapp              # Check error logs
pm2 restart myapp --update-env
```

### 502 Bad Gateway
```bash
# Check if app is running
pm2 status

# Check port
sudo netstat -tlnp | grep 3000

# Check nginx config
sudo nginx -t
```

### SSL Certificate Issues
```bash
sudo certbot renew
sudo systemctl reload nginx
```

> 📖 See [ssl/SSL-TROUBLESHOOTING.md](ssl/SSL-TROUBLESHOOTING.md) for detailed fixes.

### High Memory Usage
```bash
# Check memory
free -h

# Restart PM2
pm2 restart myapp
```

---

## Part 8: Backups

### Setup Automatic Backups
```bash
# Create backup script
nano ~/backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/home/deploy/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
mysqldump -u root -p'YOUR_PASSWORD' myapp_db > $BACKUP_DIR/db_$DATE.sql

# Backup app files
tar -czf $BACKUP_DIR/app_$DATE.tar.gz /var/www/apps/myapp

# Keep only last 7 days
find $BACKUP_DIR -type f -mtime +7 -delete
```

```bash
chmod +x ~/backup.sh

# Add to crontab (daily at 2 AM)
crontab -e
0 2 * * * /home/deploy/backup.sh
```

---

## Part 9: Monitoring

### Setup Basic Monitoring
```bash
# Install htop
sudo apt install htop

# Monitor resources
htop

# PM2 monitoring
pm2 monit
```

### Setup PM2 Web Monitoring (Optional)
```bash
pm2 install pm2-server-monit
```

---

## Security Checklist

✅ SSH password authentication disabled  
✅ Firewall (UFW) enabled  
✅ Fail2Ban configured  
✅ SSL certificate installed  
✅ Regular security updates enabled  
✅ Strong passwords for databases  
✅ Non-root user for deployments  
✅ Environment variables not in code  

---

## Cost Estimate

- **VPS**: $10-12/month (2GB RAM)
- **Domain**: $10-15/year
- **SSL**: Free (Let's Encrypt)
- **Total**: ~$12/month + domain

Much cheaper than shared hosting with full control!

---

## Need Help?

Common issues and solutions in Part 7: Troubleshooting

For more help:
1. Check PM2 logs: `pm2 logs myapp`
2. Check Nginx logs: `sudo tail -f /var/log/nginx/error.log`
3. Check system logs: `sudo journalctl -xe`
