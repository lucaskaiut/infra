#!/bin/sh
set -e

APP_DIR="/var/www/html"
cd "$APP_DIR"
log() { echo "[chat-one] $*"; }

# 1) .env
if [ ! -f .env ] && [ -f .env.example ]; then
    cp .env.example .env
    log ".env criado"
fi

# 2) APP_KEY
if ! grep -q '^APP_KEY=[^[:space:]]' .env 2>/dev/null; then
    log "APP_KEY vazia - gerando..."
    php artisan key:generate --force --no-interaction
    rm -f bootstrap/cache/config.php
    php artisan config:clear --no-interaction 2>/dev/null || true
fi

# 3) Dump autoload
if [ ! -f vendor/autoload.php ] || [ ! -f bootstrap/cache/packages.php ]; then
    log "composer dump-autoload..."
    composer dump-autoload --no-interaction --optimize --classmap-authoritative
fi

# 4) Storage link
if [ ! -e public/storage ]; then
    php artisan storage:link --no-interaction || true
fi

# 5) Aguarda MySQL - PHP le env vars direto do Docker
log "Aguardando MySQL..."
tries=0
while [ "$tries" -lt 90 ]; do
    if php -r '
        $h = getenv("DB_HOST") ?: "mysql";
        $p = getenv("DB_PORT") ?: "3306";
        $d = getenv("DB_DATABASE") ?: "chat_one";
        $u = getenv("DB_USERNAME") ?: "chatone";
        $w = getenv("DB_PASSWORD") ?: "";
        try {
            new PDO("mysql:host=$h;port=$p;dbname=$d", $u, $w, [PDO::ATTR_TIMEOUT => 3]);
            exit(0);
        } catch (Throwable $e) { exit(1); }
    ' 2>/dev/null; then
        log "MySQL disponivel"
        break
    fi
    tries=$((tries + 1))
    sleep 2
done
[ "$tries" -ge 90 ] && { log "ERRO: MySQL indisponivel"; exit 1; }

# 6) Cache
log "Otimizando caches..."
php artisan config:cache --no-interaction || true
php artisan route:cache --no-interaction || true
php artisan view:cache --no-interaction || true
php artisan event:cache --no-interaction || true

# 7) Migrations (não falha se tabelas já existem - race condition entre containers)
if [ "${CONTAINER_ROLE:-web}" = "web" ]; then
    log "Executando migrations..."
    php artisan migrate --force --no-interaction || log "AVISO: migrations falharam (tabelas ja existem?)"
fi

# 8) Permissoes
mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
chmod -R ug+rwX storage bootstrap/cache 2>/dev/null || true

# Dispatch: se tem argumentos (command do docker), executa direto
if [ $# -gt 0 ]; then
    log "Executando comando: $*"
    exec "$@"
fi

# Ou pelo CONTAINER_ROLE
case "${CONTAINER_ROLE:-web}" in
    worker)
        log "Iniciando queue worker..."
        exec php artisan queue:work redis --queue=whatsapp-webhooks,default --sleep=1 --tries=3 --max-time=3600
        ;;
    reverb)
        log "Iniciando Reverb..."
        exec php artisan reverb:start --host=0.0.0.0 --port=8080 --no-interaction
        ;;
    *)
        log "Iniciando nginx + php-fpm..."
        exec /usr/bin/supervisord -c /etc/supervisord.conf
        ;;
esac
