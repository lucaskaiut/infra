#!/bin/sh
set -eu
cd /var/www/html
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
chmod -R ug+rwX storage bootstrap/cache

role="${CONTAINER_ROLE:-web}"

wait_mysql() {
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

wait_redis() {
  echo "Waiting for Redis..."
  i=0
  while [ "$i" -lt 90 ]; do
    if php -r "
      \$host = getenv('REDIS_HOST') ?: '127.0.0.1';
      \$port = (int) (getenv('REDIS_PORT') ?: 6379);
      \$pw = getenv('REDIS_PASSWORD');
    if (\$pw === false || \$pw === '') \$pw = null;
    elseif (strtolower(trim(\$pw)) === 'null') \$pw = null;
      try {
        \$r = new Redis();
        if (!\$r->connect(\$host, \$port, 2.0)) exit(1);
        if (\$pw !== null && !\$r->auth(\$pw)) exit(1);
        exit(\$r->ping() ? 0 : 1);
      } catch (Throwable \$e) {
        exit(1);
      }
    " 2>/dev/null; then
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  echo "Redis not reachable"
  exit 1
}

wait_opensearch() {
  url="${OPENSEARCH_URL:-http://opensearch:9200}"
  echo "Waiting for OpenSearch (${url})..."
  i=0
  while [ "$i" -lt 90 ]; do
    if wget -qO- "$url" >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  echo "OpenSearch not reachable"
  exit 1
}

if [ "$role" = "worker" ]; then
  wait_mysql
  wait_redis
  wait_opensearch
  exec su-exec www-data php artisan queue:work redis --queue=logs --tries=3 --timeout=120
fi

wait_mysql
php artisan migrate --force --isolated

exec /usr/bin/supervisord -c /etc/supervisord.conf
