#!/bin/sh
set -eu
cd /var/www/html
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
chmod -R ug+rwX storage bootstrap/cache

role="${CONTAINER_ROLE:-web}"

if [ "$role" = "worker" ]; then
  exec su-exec www-data php artisan queue:work --sleep=3 --tries=3 --max-time=3600
fi

if [ "$role" = "scheduler" ]; then
  exec su-exec www-data sh -c 'while true; do php artisan schedule:run --verbose --no-interaction; sleep 60; done'
fi

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
    break
  fi
  i=$((i + 1))
  sleep 2
done

if [ "$i" -ge 90 ]; then
  echo "MySQL not reachable"
  exit 1
fi

i=0
while [ "$i" -lt 90 ]; do
  if php artisan migrate --force --isolated; then
    break
  fi
  i=$((i + 1))
  sleep 2
done
if [ "$i" -ge 90 ]; then
  echo "migrate failed after retries"
  exit 1
fi

exec /usr/bin/supervisord -c /etc/supervisord.conf
