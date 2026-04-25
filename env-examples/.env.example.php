# ============================================================
# Raw PHP .env — Environment Variables
# ============================================================
#
# Copy this to your PHP project root:
#   cp .env.example.php /var/www/apps/yourapp/.env
#
# Load in your PHP code with:
#   1. vlucas/phpdotenv (composer require vlucas/phpdotenv)
#      $dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
#      $dotenv->load();
#      $dbHost = $_ENV['DB_HOST'];
#
#   2. Or parse manually:
#      $env = parse_ini_file('.env');
#      $dbHost = $env['DB_HOST'];
#
# NEVER commit .env to version control!
# ============================================================

# ------------------------------------------------------------
# APPLICATION
# ------------------------------------------------------------
APP_NAME="My PHP App"
APP_ENV=production                       # development | staging | production
APP_DEBUG=false                          # true in dev, ALWAYS false in production
APP_URL=https://yourdomain.com
APP_TIMEZONE=UTC

# Secret key for encryption/hashing (generate a random 32+ char string)
APP_SECRET=your_random_secret_key_here_min_32_characters

# ------------------------------------------------------------
# DATABASE — MySQL
# ------------------------------------------------------------
DB_DRIVER=mysql                          # mysql | pgsql | sqlite
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=myapp_db
DB_USERNAME=myapp_user
DB_PASSWORD=your_strong_password_here
DB_CHARSET=utf8mb4
DB_COLLATION=utf8mb4_unicode_ci

# Full DSN (for PDO)
# DB_DSN=mysql:host=127.0.0.1;port=3306;dbname=myapp_db;charset=utf8mb4

# PostgreSQL (uncomment if using PostgreSQL):
# DB_DRIVER=pgsql
# DB_HOST=127.0.0.1
# DB_PORT=5432
# DB_DATABASE=myapp_db
# DB_USERNAME=myapp_user
# DB_PASSWORD=your_strong_password_here

# SQLite (uncomment if using SQLite):
# DB_DRIVER=sqlite
# DB_DATABASE=/var/www/apps/yourapp/database/app.sqlite

# ------------------------------------------------------------
# SESSION
# ------------------------------------------------------------
SESSION_DRIVER=file                      # file | database | redis
SESSION_LIFETIME=120                     # Minutes
SESSION_NAME=myapp_session
SESSION_PATH=/
SESSION_SECURE=true                      # true if using HTTPS
SESSION_HTTPONLY=true                     # Prevent JavaScript access

# If using database sessions:
# SESSION_TABLE=sessions

# If using Redis sessions:
# SESSION_REDIS_HOST=127.0.0.1
# SESSION_REDIS_PORT=6379

# ------------------------------------------------------------
# MAIL / SMTP
# ------------------------------------------------------------
MAIL_DRIVER=smtp                         # smtp | sendmail | mail
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your_email@gmail.com
MAIL_PASSWORD=your_app_password
MAIL_ENCRYPTION=tls                      # tls | ssl | null
MAIL_FROM_ADDRESS=noreply@yourdomain.com
MAIL_FROM_NAME="${APP_NAME}"

# PHPMailer settings:
# MAIL_SMTP_AUTH=true
# MAIL_SMTP_SECURE=tls

# ------------------------------------------------------------
# FILE UPLOADS
# ------------------------------------------------------------
UPLOAD_MAX_SIZE=10M                      # Max file upload size
UPLOAD_DIR=uploads/                      # Upload directory relative to public/
UPLOAD_ALLOWED_TYPES=jpg,jpeg,png,gif,pdf,doc,docx

# ------------------------------------------------------------
# REDIS / CACHING
# ------------------------------------------------------------
# CACHE_DRIVER=file                      # file | redis | memcached
# CACHE_DIR=/tmp/myapp_cache

# REDIS_HOST=127.0.0.1
# REDIS_PORT=6379
# REDIS_PASSWORD=null

# Memcached
# MEMCACHED_HOST=127.0.0.1
# MEMCACHED_PORT=11211

# ------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------
LOG_LEVEL=error                          # debug | info | warning | error
LOG_FILE=logs/app.log                    # Relative to project root
LOG_MAX_FILES=14                         # Days to keep

# ------------------------------------------------------------
# SECURITY
# ------------------------------------------------------------
# CORS
CORS_ALLOWED_ORIGINS=https://yourdomain.com
CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE
CORS_ALLOWED_HEADERS=Content-Type,Authorization

# Rate limiting
RATE_LIMIT_REQUESTS=60                   # Requests per window
RATE_LIMIT_WINDOW=60                     # Window in seconds

# CSRF token name
CSRF_TOKEN_NAME=csrf_token

# ------------------------------------------------------------
# API KEYS & THIRD-PARTY SERVICES
# ------------------------------------------------------------
# STRIPE_KEY=pk_live_xxxxx
# STRIPE_SECRET=sk_live_xxxxx

# GOOGLE_MAPS_API_KEY=
# RECAPTCHA_SITE_KEY=
# RECAPTCHA_SECRET_KEY=

# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
# AWS_DEFAULT_REGION=us-east-1
# AWS_BUCKET=your-bucket-name

# SENTRY_DSN=https://xxxxx@sentry.io/xxxxx

# ------------------------------------------------------------
# PHP-SPECIFIC SETTINGS (used by some frameworks)
# These can also be set in php.ini or .htaccess
# ------------------------------------------------------------
# PHP_DISPLAY_ERRORS=Off
# PHP_ERROR_REPORTING=E_ALL
# PHP_MEMORY_LIMIT=256M
# PHP_MAX_EXECUTION_TIME=60
# PHP_POST_MAX_SIZE=12M
# PHP_UPLOAD_MAX_FILESIZE=10M
