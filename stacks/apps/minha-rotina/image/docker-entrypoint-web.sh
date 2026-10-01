#!/bin/sh
set -eu
cd /var/www/html
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
chmod -R ug+rwX storage bootstrap/cache

role="${CONTAINER_ROLE:-web}"

wait_for_table() {
  table="${1:-jobs}"
  echo "Waiting for MySQL and table ${table}..."
  i=0
  while [ "$i" -lt 120 ]; do
    if php -r "
      try {
        \$pdo = new PDO(
          'mysql:host=' . getenv('DB_HOST') . ';port=' . (getenv('DB_PORT') ?: '3306') . ';dbname=' . getenv('DB_DATABASE'),
          getenv('DB_USERNAME'),
          getenv('DB_PASSWORD')
        );
        \$pdo->query('select 1 from \`' . getenv('WAIT_TABLE') . '\` limit 1');
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
  echo "MySQL not reachable or table ${table} missing"
  return 1
}

export WAIT_TABLE="migrations"

if [ "$role" = "worker" ]; then
  export WAIT_TABLE="jobs"
  wait_for_table "jobs"
  exec su-exec www-data php artisan queue:work --sleep=3 --tries=3 --max-time=3600
fi

if [ "$role" = "scheduler" ]; then
  export WAIT_TABLE="jobs"
  wait_for_table "jobs"
  exec su-exec www-data sh -c 'while true; do php artisan schedule:run --verbose --no-interaction; sleep 60; done'
fi

wait_for_table "migrations"

echo "Running migrations (com lock para múltiplas réplicas)..."
# As réplicas sobem em paralelo (start-first); o flock no volume compartilhado
# serializa as migrations e evita "table already exists" no primeiro deploy.
flock -w 180 /var/www/html/storage/app/public/.migrate.lock \
  php artisan migrate --force \
  || echo "WARNING: migrations failed — container will start with current schema" >&2

php artisan storage:link --no-interaction >/dev/null 2>&1 || true
php artisan optimize:clear --no-interaction >/dev/null 2>&1 || true

exec /usr/bin/supervisord -c /etc/supervisord.conf
