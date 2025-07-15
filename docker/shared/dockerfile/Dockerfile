# Multi-stage Laravel Production Docker Image
# Production-ready with OPcache, Redis, SSL support

# Stage 1: Build stage for assets and dependencies
FROM node:20-alpine AS assets

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY vite.config.js ./
COPY tailwind.config.js ./
COPY postcss.config.js ./

# Install Node dependencies
RUN npm ci --only=production

# Copy source files for asset building
COPY resources ./resources
COPY public ./public

# Build assets
RUN npm run build

# Stage 2: PHP Production Image
FROM php:8.3-fpm-alpine AS production

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    mysql-client \
    curl \
    zip \
    unzip \
    git \
    oniguruma-dev \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    gettext-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        mysqli \
        gd \
        zip \
        opcache \
        bcmath \
        intl \
        gettext \
        exif \
        pcntl

# Install Redis extension
RUN pecl install redis && docker-php-ext-enable redis

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create application directory
WORKDIR /var/www/html

# Copy composer files
COPY composer.json composer.lock ./

# Install PHP dependencies (production only)
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-progress

# Copy application code
COPY . .

# Copy built assets from assets stage
COPY --from=assets /app/public/build ./public/build

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

# Copy configuration files
COPY docker/shared/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/shared/nginx/default.conf /etc/nginx/http.d/default.conf
COPY docker/shared/dockerfile/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY docker/shared/dockerfile/opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini
COPY docker/shared/dockerfile/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create necessary directories
RUN mkdir -p /var/log/supervisor /var/log/nginx /var/log/php

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Stage 3: Development Image (extends production)
FROM production AS development

# Install development dependencies
RUN apk add --no-cache \
    nodejs \
    npm

# Install Xdebug for development
RUN pecl install xdebug \
    && docker-php-ext-enable xdebug

# Copy development PHP config
COPY docker/shared/dockerfile/php-dev.ini /usr/local/etc/php/conf.d/99-dev.ini

# Install development Composer dependencies
RUN composer install --optimize-autoloader --no-interaction --no-progress

# Development command
CMD ["php-fpm"]