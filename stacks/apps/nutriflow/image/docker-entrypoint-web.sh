#!/bin/sh
set -eu
cd /var/www/html
mkdir -p storage/app/public storage/app/private storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
chmod -R ug+rwX storage bootstrap/cache

# A API do NutriFlow não usa fila nem agendador: só existe o papel "web".
echo "Waiting for MySQL..."
i=0
until php -r "
  try {
    new PDO('mysql:host=' . getenv('DB_HOST') . ';port=' . (getenv('DB_PORT') ?: '3306') . ';dbname=' . getenv('DB_DATABASE'), getenv('DB_USERNAME'), getenv('DB_PASSWORD'));
    exit(0);
  } catch (Throwable \$e) { exit(1); }
" 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -ge 120 ]; then echo "MySQL not reachable" >&2; break; fi
  sleep 2
done

# Migrations + base de alimentos TACO (seeders idempotentes; a conta demo NÃO é criada em produção).
# O flock no volume compartilhado serializa réplicas que sobem em paralelo (start-first).
echo "Running migrations and TACO seed..."
flock /var/www/html/storage/app/public/.migrate.lock sh -c '
  php artisan migrate --force &&
  php artisan db:seed --class="Database\\Seeders\\FoodCategorySeeder" --force &&
  php artisan db:seed --class="Database\\Seeders\\TacoFoodSeeder" --force
' || echo "WARNING: migrations/seed failed — container will start with current schema" >&2

php artisan optimize:clear --no-interaction >/dev/null 2>&1 || true

exec /usr/bin/supervisord -c /etc/supervisord.conf
