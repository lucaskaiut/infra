FROM composer:2 AS vendor
WORKDIR /app
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY chat-one/api/composer.json chat-one/api/composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs
COPY chat-one/api/ .
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
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    wget \
    $PHPIZE_DEPS \
  && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
  && docker-php-ext-install -j"$(nproc)" pdo_mysql mbstring exif pcntl bcmath intl zip opcache gd \
  && pecl install redis \
  && docker-php-ext-enable redis \
  && apk del $PHPIZE_DEPS \
  && rm -rf /tmp/pear

WORKDIR /var/www/html
COPY --from=vendor /app /var/www/html

COPY image/nginx.conf /etc/nginx/http.d/default.conf
COPY image/supervisord.conf /etc/supervisord.conf
COPY image/www-fpm-override.conf /usr/local/etc/php-fpm.d/zz-www.conf
COPY image/php-custom.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY image/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh \
  && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
