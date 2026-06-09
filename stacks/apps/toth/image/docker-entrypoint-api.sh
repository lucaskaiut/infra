#!/bin/sh
set -eu

if [ "${TOTH_BOOTSTRAP:-0}" = "1" ]; then
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

  if [ -n "${VECTOR_DB_HOST:-}" ]; then
    echo "Waiting for PostgreSQL (vector)..."
    j=0
    while [ "$j" -lt 60 ]; do
      if php -r "
        try {
          new PDO(
            'pgsql:host=' . getenv('VECTOR_DB_HOST') . ';port=' . (getenv('VECTOR_DB_PORT') ?: '5432') . ';dbname=' . getenv('VECTOR_DB_DATABASE'),
            getenv('VECTOR_DB_USERNAME'),
            getenv('VECTOR_DB_PASSWORD')
          );
          exit(0);
        } catch (Throwable \$e) {
          exit(1);
        }
      " 2>/dev/null; then
        break
      fi
      j=$((j + 1))
      sleep 2
    done
  fi

  php artisan migrate --force
  if php artisan list --raw 2>/dev/null | grep -qx 'vector:migrate'; then
    php artisan vector:migrate --force
  fi
  php artisan config:cache
  php artisan route:cache
  php artisan view:cache
fi

exec docker-php-entrypoint php-fpm
