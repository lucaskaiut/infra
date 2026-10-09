#!/bin/sh
set -eu
cd /var/www/html

mkdir -p storage/app/artifacts storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
chmod -R ug+rwX storage bootstrap/cache

role="${CONTAINER_ROLE:-web}"

wait_for_mysql() {
  echo "Waiting for MySQL..."
  i=0
  while [ "$i" -lt 90 ]; do
    if php -r "
      try {
        new PDO(
          'mysql:host=' . getenv('DB_HOST') . ';port=' . (getenv('DB_PORT') ?: '3306') . ';dbname=' . getenv('DB_DATABASE'),
          getenv('DB_USERNAME'),
          getenv('DB_PASSWORD')
        );
        exit(0);
      } catch (Throwable \$e) {
        exit(1);
      }
    " 2>/dev/null; then
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  echo "MySQL not reachable"
  exit 1
}

if [ "$role" = "scheduler" ]; then
  wait_for_mysql
  exec su-exec www-data sh -c 'while true; do php artisan schedule:run --verbose --no-interaction; sleep 60; done'
fi

wait_for_mysql

echo "Running migrations..."
php artisan migrate --force || echo "WARNING: migrations failed — container will start with current schema" >&2

php artisan optimize:clear --no-interaction >/dev/null 2>&1 || true

exec /usr/bin/supervisord -c /etc/supervisord.conf
