#!/bin/bash

#############################################
# VPS Auto Setup Script
# This script sets up a fresh Ubuntu VPS with:
# - Security hardening
# - Nginx, PHP, MySQL, Node.js, PM2
# - SSL with Certbot
# - CI/CD setup
# - Firewall configuration
#############################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration Variables - EDIT THESE!
NEW_USERNAME="deploy"           # Your sudo user
YOUR_SSH_PUBLIC_KEY=""          # Your SSH public key (paste from ~/.ssh/id_rsa.pub)
YOUR_DOMAIN=""                  # Your domain (optional, for SSL)
YOUR_EMAIL=""                   # Your email for SSL cert
MYSQL_ROOT_PASSWORD=""          # MySQL root password (will generate if empty)
NODE_VERSION="20"               # Node.js version
PHP_VERSION="8.2"               # PHP version

#############################################
# Helper Functions
#############################################

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

#############################################
# Validation
#############################################

if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

if [ -z "$YOUR_SSH_PUBLIC_KEY" ]; then
    print_warning "SSH_PUBLIC_KEY is not set. You'll need to add it manually later."
fi

#############################################
# 1. System Update
#############################################

print_status "Updating system packages..."
apt update && apt upgrade -y
apt install -y curl wget git ufw fail2ban unzip software-properties-common

#############################################
# 2. Create Sudo User
#############################################

print_status "Creating sudo user: $NEW_USERNAME..."

if id "$NEW_USERNAME" &>/dev/null; then
    print_warning "User $NEW_USERNAME already exists, skipping creation"
else
    useradd -m -s /bin/bash "$NEW_USERNAME"
    usermod -aG sudo "$NEW_USERNAME"
    
    # Set up SSH for new user
    mkdir -p /home/$NEW_USERNAME/.ssh
    chmod 700 /home/$NEW_USERNAME/.ssh
    
    if [ -n "$YOUR_SSH_PUBLIC_KEY" ]; then
        echo "$YOUR_SSH_PUBLIC_KEY" > /home/$NEW_USERNAME/.ssh/authorized_keys
        chmod 600 /home/$NEW_USERNAME/.ssh/authorized_keys
        chown -R $NEW_USERNAME:$NEW_USERNAME /home/$NEW_USERNAME/.ssh
        print_status "SSH key added for $NEW_USERNAME"
    fi
fi

#############################################
# 3. Security: SSH Hardening
#############################################

print_status "Hardening SSH configuration..."

# Backup original SSH config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Configure SSH
cat > /etc/ssh/sshd_config.d/99-custom.conf <<EOF
# Disable root login with password
PermitRootLogin prohibit-password

# Disable password authentication (key-based only)
PasswordAuthentication no
PubkeyAuthentication yes

# Other security settings
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# Restart SSH (don't disconnect current session)
systemctl reload sshd

print_status "SSH hardened - root password login disabled"

#############################################
# 4. Firewall Setup (UFW)
#############################################

print_status "Configuring firewall..."

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

print_status "Firewall enabled (SSH, HTTP, HTTPS allowed)"

#############################################
# 5. Fail2Ban Setup
#############################################

print_status "Setting up Fail2Ban..."

systemctl enable fail2ban
systemctl start fail2ban

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
EOF

systemctl restart fail2ban

print_status "Fail2Ban configured"

#############################################
# 6. Install Nginx
#############################################

print_status "Installing Nginx..."

apt install -y nginx
systemctl enable nginx
systemctl start nginx

# Create default server block
cat > /etc/nginx/sites-available/default <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    
    server_name _;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

nginx -t && systemctl reload nginx

print_status "Nginx installed and configured"

#############################################
# 7. Install PHP
#############################################

print_status "Installing PHP $PHP_VERSION..."

add-apt-repository -y ppa:ondrej/php
apt update
apt install -y php$PHP_VERSION-fpm php$PHP_VERSION-mysql php$PHP_VERSION-mbstring \
    php$PHP_VERSION-xml php$PHP_VERSION-curl php$PHP_VERSION-zip php$PHP_VERSION-gd \
    php$PHP_VERSION-intl php$PHP_VERSION-bcmath

systemctl enable php$PHP_VERSION-fpm
systemctl start php$PHP_VERSION-fpm

print_status "PHP $PHP_VERSION installed"

#############################################
# 8. Install MySQL
#############################################

print_status "Installing MySQL..."

# Generate random password if not set
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
    print_warning "Generated MySQL root password: $MYSQL_ROOT_PASSWORD"
    echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD" >> /root/credentials.txt
fi

# Install MySQL
apt install -y mysql-server

# Secure MySQL installation
mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

systemctl enable mysql
systemctl start mysql

print_status "MySQL installed and secured"

#############################################
# 9. Install Node.js & NPM
#############################################

print_status "Installing Node.js $NODE_VERSION..."

curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash -
apt install -y nodejs

print_status "Node.js $(node -v) and NPM $(npm -v) installed"

#############################################
# 10. Install PM2
#############################################

print_status "Installing PM2..."

npm install -g pm2

# Setup PM2 startup script
env PATH=$PATH:/usr/bin pm2 startup systemd -u $NEW_USERNAME --hp /home/$NEW_USERNAME

print_status "PM2 installed"

#############################################
# 11. Install Certbot (SSL)
#############################################

print_status "Installing Certbot..."

apt install -y certbot python3-certbot-nginx

print_status "Certbot installed"

if [ -n "$YOUR_DOMAIN" ] && [ -n "$YOUR_EMAIL" ]; then
    print_status "Setting up SSL for $YOUR_DOMAIN..."
    certbot --nginx -d $YOUR_DOMAIN -d www.$YOUR_DOMAIN --non-interactive --agree-tos -m $YOUR_EMAIL
    print_status "SSL certificate installed for $YOUR_DOMAIN"
else
    print_warning "Domain and email not set. Run this manually later:"
    echo "  sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com"
fi

#############################################
# 12. Setup Directory Structure
#############################################

print_status "Setting up project directories..."

mkdir -p /var/www/apps
chown -R $NEW_USERNAME:$NEW_USERNAME /var/www/apps

# Create sample nginx config for Node.js apps
cat > /etc/nginx/sites-available/nodejs-template <<'EOF'
server {
    listen 80;
    server_name YOUR_DOMAIN;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

print_status "Project directories created"

#############################################
# 13. Install Additional Tools
#############################################

print_status "Installing additional tools..."

# Install build essentials
apt install -y build-essential

# Install Composer (PHP package manager)
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

print_status "Additional tools installed"

#############################################
# 14. Setup Automatic Security Updates
#############################################

print_status "Enabling automatic security updates..."

apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

print_status "Automatic security updates enabled"

#############################################
# 15. Setup Basic CI/CD with GitHub Actions
#############################################

print_status "Setting up CI/CD prerequisites..."

# Create deploy script template
cat > /home/$NEW_USERNAME/deploy.sh <<'EOF'
#!/bin/bash

# Sample deployment script
# Customize this for your application

APP_DIR="/var/www/apps/myapp"
APP_NAME="myapp"

cd $APP_DIR

# Pull latest code
git pull origin main

# Install dependencies
npm install --production

# Build if needed
npm run build

# Restart with PM2
pm2 restart $APP_NAME || pm2 start ecosystem.config.js

pm2 save

echo "Deployment completed!"
EOF

chmod +x /home/$NEW_USERNAME/deploy.sh
chown $NEW_USERNAME:$NEW_USERNAME /home/$NEW_USERNAME/deploy.sh

print_status "CI/CD prerequisites setup"

#############################################
# 16. Setup Swap (if needed)
#############################################

if [ $(free -m | awk '/^Swap:/ {print $2}') -eq 0 ]; then
    print_status "Creating 2GB swap file..."
    
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    
    print_status "Swap file created"
fi

#############################################
# Final Summary
#############################################

echo ""
echo "=========================================="
echo -e "${GREEN}VPS Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "✓ System updated and secured"
echo "✓ User created: $NEW_USERNAME"
echo "✓ SSH hardened (password auth disabled)"
echo "✓ Firewall enabled (UFW)"
echo "✓ Fail2Ban configured"
echo "✓ Nginx installed"
echo "✓ PHP $PHP_VERSION installed"
echo "✓ MySQL installed"
echo "✓ Node.js $(node -v) installed"
echo "✓ PM2 installed"
echo "✓ Certbot installed"
echo ""
echo "=========================================="
echo "Important Information:"
echo "=========================================="
echo ""
echo "1. New sudo user: $NEW_USERNAME"
echo "2. MySQL root password saved to: /root/credentials.txt"
echo ""
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Test SSH connection as new user:"
echo "   ssh $NEW_USERNAME@YOUR_SERVER_IP"
echo ""
echo "2. Deploy your Node.js app:"
echo "   - Upload to /var/www/apps/yourapp"
echo "   - Create nginx config from template:"
echo "     sudo cp /etc/nginx/sites-available/nodejs-template /etc/nginx/sites-available/yourapp"
echo "   - Edit and enable it"
echo "   - Get SSL: sudo certbot --nginx -d yourdomain.com"
echo ""
echo "3. Setup GitHub Actions for CI/CD:"
echo "   - Add server SSH key to GitHub secrets"
echo "   - Use the deploy script: /home/$NEW_USERNAME/deploy.sh"
echo ""
echo "=========================================="
echo -e "${YELLOW}IMPORTANT:${NC} Test SSH access before logging out!"
echo "=========================================="
echo ""
