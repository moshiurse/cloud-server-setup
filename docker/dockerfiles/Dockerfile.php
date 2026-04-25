# ============================================================
# Dockerfile for Raw PHP Application
# ============================================================
# Build:  docker build -f Dockerfile.php -t myapp .
# Run:    docker run -p 8080:80 myapp
# ============================================================

FROM php:8.2-fpm-alpine AS base

# Install PHP extensions
RUN apk add --no-cache \
        libpng-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        libzip-dev \
        icu-dev \
        oniguruma-dev \
        curl-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        intl \
        mbstring \
        curl \
        opcache \
        bcmath

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# PHP production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Custom PHP settings
COPY docker/php/custom.ini $PHP_INI_DIR/conf.d/custom.ini 2>/dev/null || true
# If no custom.ini exists, create defaults:
RUN echo "upload_max_filesize = 50M" >> $PHP_INI_DIR/conf.d/docker-defaults.ini \
    && echo "post_max_size = 52M" >> $PHP_INI_DIR/conf.d/docker-defaults.ini \
    && echo "memory_limit = 256M" >> $PHP_INI_DIR/conf.d/docker-defaults.ini \
    && echo "max_execution_time = 60" >> $PHP_INI_DIR/conf.d/docker-defaults.ini \
    && echo "opcache.enable = 1" >> $PHP_INI_DIR/conf.d/docker-defaults.ini \
    && echo "opcache.memory_consumption = 128" >> $PHP_INI_DIR/conf.d/docker-defaults.ini \
    && echo "opcache.validate_timestamps = 0" >> $PHP_INI_DIR/conf.d/docker-defaults.ini

WORKDIR /var/www/html

# Copy application code
COPY . /var/www/html

# Install Composer dependencies (if composer.json exists)
RUN if [ -f composer.json ]; then \
        composer install --no-dev --optimize-autoloader --no-interaction; \
    fi

# Set permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

EXPOSE 9000

CMD ["php-fpm"]
