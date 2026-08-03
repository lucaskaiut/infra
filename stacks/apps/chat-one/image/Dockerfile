FROM composer:2 AS vendor
WORKDIR /app
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY chat-one/api/composer.json chat-one/api/composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --ignore-platform-reqs
COPY chat-one/api/ .
RUN rm -rf bootstrap/cache/*.php 2>/dev/null; true
RUN composer install --no-dev --no-scripts --optimize-autoloader --classmap-authoritative --ignore-platform-reqs

FROM php:8.4-fpm
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    wget \
    ffmpeg \
    libicu-dev \
    libzip-dev \
    libonig-dev \
    libpng-dev \
    libjpeg-dev \
    libwebp-dev \
    libfreetype-dev \
  && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
  && docker-php-ext-install -j"$(nproc)" pdo_mysql mbstring exif pcntl bcmath intl zip opcache gd \
  && pecl install redis \
  && docker-php-ext-enable redis \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/pear

WORKDIR /var/www/html
COPY --from=vendor /app /var/www/html

COPY image/nginx.conf /etc/nginx/sites-available/default
COPY image/supervisord.conf /etc/supervisord.conf
COPY image/www-fpm-override.conf /usr/local/etc/php-fpm.d/zz-www.conf
COPY image/php-custom.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY image/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh \
  && rm -f /etc/nginx/sites-enabled/default \
  && ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default \
  && mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
  && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
