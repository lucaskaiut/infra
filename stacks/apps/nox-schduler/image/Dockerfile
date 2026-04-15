FROM composer:2 AS vendor
WORKDIR /app
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY nox-schduler/api/composer.json nox-schduler/api/composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs
COPY nox-schduler/api/ .
RUN composer install --no-dev --optimize-autoloader --classmap-authoritative --ignore-platform-reqs

FROM node:22-alpine AS assets
WORKDIR /app
COPY nox-schduler/api/package.json ./
RUN npm install
COPY nox-schduler/api/ .
RUN npm run build

FROM php:8.3-fpm-alpine
RUN apk add --no-cache \
    nginx \
    supervisor \
    su-exec \
    icu-dev \
    libzip-dev \
    oniguruma-dev \
    linux-headers \
    wget \
    $PHPIZE_DEPS \
  && docker-php-ext-install -j"$(nproc)" pdo_mysql mbstring exif pcntl bcmath intl zip opcache \
  && pecl install redis \
  && docker-php-ext-enable redis \
  && apk del $PHPIZE_DEPS \
  && rm -rf /tmp/pear

WORKDIR /var/www/html
COPY --from=vendor /app /var/www/html
COPY --from=assets /app/public/build /var/www/html/public/build

COPY image/nginx.conf /etc/nginx/http.d/default.conf
COPY image/supervisord.conf /etc/supervisord.conf
COPY image/www-fpm-override.conf /usr/local/etc/php-fpm.d/zz-www.conf
COPY image/docker-entrypoint-web.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh \
  && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
