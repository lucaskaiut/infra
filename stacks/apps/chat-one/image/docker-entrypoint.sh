#!/bin/sh
set -e
APP_DIR="/var/www/html"
cd "$APP_DIR"
log() { echo "[chat-one] $*"; }

if [ ! -f .env ] && [ -f .env.example ]; then
    cp .env.example .env
    log ".env criado"
fi

if ! grep -q '^APP_KEY=[^[:space:]]' .env 2>/dev/null; then
    log "APP_KEY vazia - gerando..."
    php artisan key:generate --force --no-interaction
fi

if [ ! -f vendor/autoload.php ] || [ ! -f bootstrap/cache/packages.php ]; then
    log "composer dump-autoload..."
    composer dump-autoload --no-interaction --optimize --classmap-authoritative
fi

if [ ! -e public/storage ]; then
    php artisan storage:link --no-interaction || true
fi
DB_HOST_VAL=***DB_PORT_VAL=***DB_DATABASE_VAL=***DB_USERNAME_VAL=***DB_PASSWORD_VAL=***export DB_HOST_VAL DB_PORT_VAL DB_DATABASE_VAL DB_USERNAME_VAL DB_PASSWORD_VAL

log "Aguardando MySQL em ${DB_HOST_VAL}:${DB_PORT_VAL}..."
tries=0
while [ "$tries" -lt 90 ]; do
    if php -r "
        \$host = getenv('DB_HOST_VAL');
        \$port = getenv('DB_PORT_VAL');
        \$db   = getenv('DB_DATABASE_VAL');
        \$user = getenv('DB_USERNAME_VAL');
        \$pass = getenv('DB_PASSWORD_VAL');
        try {
            new PDO(\"mysql:host=\$host;port=\$port;dbname=\$db\", \$user, \$pass, [PDO::ATTR_TIMEOUT => 3]);
            exit(0);
        } catch (Throwable \$e) {
            exit(1);
        }
    " 2>/dev/null; then
        log "MySQL disponivel"
        break
    fi
    tries=$((tries + 1))
    sleep 2
done
[ "$tries" -ge 90 ] && { log "ERRO: MySQL indisponivel"; exit 1; }

log "Otimizando caches..."
php artisan config:cache --no-interaction || true
php artisan route:cache --no-interaction || true
php artisan view:cache --no-interaction || true
php artisan event:cache --no-interaction || true

if [ "${CONTAINER_ROLE:-web}" = "web" ]; then
    log "Executando migrations..."
    php artisan migrate --force --no-interaction
fi

mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache
chmod -R ug+rwX storage bootstrap/cache

log "Inicializacao concluida. Iniciando nginx + php-fpm..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
