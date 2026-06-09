FROM composer:2 AS vendor
WORKDIR /app
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY toth/api/composer.json toth/api/composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs
COPY toth/api/ .
RUN composer install --no-dev --optimize-autoloader --classmap-authoritative --ignore-platform-reqs

FROM node:22-alpine AS assets
WORKDIR /app
COPY toth/api/package.json toth/api/package-lock.json* ./
RUN npm ci --ignore-scripts 2>/dev/null || npm install
COPY toth/api/ .
RUN npm run build

FROM php:8.4-fpm-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libpq-dev \
    zip \
    unzip \
  && docker-php-ext-install pdo_mysql pdo_pgsql mbstring exif pcntl bcmath gd zip \
  && pecl install redis \
  && docker-php-ext-enable redis \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/html
COPY --from=vendor /app /var/www/html
COPY --from=assets /app/public/build /var/www/html/public/build

COPY toth/docker/php/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY image/docker-entrypoint-api.sh /usr/local/bin/docker-entrypoint-api.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/docker-entrypoint-api.sh \
  && chown -R www-data:www-data storage bootstrap/cache

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/docker-entrypoint-api.sh"]
