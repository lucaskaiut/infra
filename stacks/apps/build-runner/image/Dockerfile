FROM composer:2 AS vendor
WORKDIR /app
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY android-build-runner/api/composer.json android-build-runner/api/composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs
COPY android-build-runner/api/ .
RUN composer install --no-dev --optimize-autoloader --classmap-authoritative --ignore-platform-reqs

FROM php:8.4-fpm-alpine
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
  && apk del $PHPIZE_DEPS \
  && rm -rf /tmp/pear

WORKDIR /var/www/html
COPY --from=vendor /app /var/www/html

COPY image/nginx.conf /etc/nginx/http.d/default.conf
COPY image/supervisord.conf /etc/supervisord.conf
COPY image/www-fpm-override.conf /usr/local/etc/php-fpm.d/zz-www.conf
COPY image/php-custom.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY image/docker-entrypoint-web.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh \
  && mkdir -p storage/app/artifacts storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
  && chown -R www-data:www-data storage bootstrap/cache

EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
