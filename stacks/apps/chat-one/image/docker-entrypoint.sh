#!/bin/sh
set -e

APP_DIR="/var/www/html"
cd "$APP_DIR"

log() { echo "[chat-one] $*"; }

# ---------------------------------------------------------------------------
# 1) .env a partir de .env.example (se não existir)
# ---------------------------------------------------------------------------
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        log ".env criado a partir de .env.example"
    fi
fi

# ---------------------------------------------------------------------------
# 2) APP_KEY (apenas se vazia)
# ---------------------------------------------------------------------------
if ! grep -q '^APP_KEY=[^[:space:]]' .env 2>/dev/null || grep -q '^APP_KEY=$' .env 2>/dev/null; then
    log "APP_KEY vazia — gerando..."
    php artisan key:generate --force --no-interaction
fi

# ---------------------------------------------------------------------------
# 3) Dump autoload com scripts (package:discover) — precisa do Redis disponível
# ---------------------------------------------------------------------------
if [ ! -f vendor/autoload.php ] || [ ! -f bootstrap/cache/packages.php ]; then
    log "Executando composer dump-autoload (package:discover)..."
    composer dump-autoload --no-interaction --optimize --classmap-authoritative
fi

# ---------------------------------------------------------------------------
# 4) Storage link
# ---------------------------------------------------------------------------
if [ ! -e public/storage ]; then
    php artisan storage:link --no-interaction || log "AVISO: storage link falhou"
fi

# ---------------------------------------------------------------------------
# 4) Cache otimizado de produção
# ---------------------------------------------------------------------------
log "Otimizando caches..."
php artisan config:cache --no-interaction || true
php artisan route:cache --no-interaction || true
php artisan view:cache --no-interaction || true
php artisan event:cache --no-interaction || true

# ---------------------------------------------------------------------------
# 5) Migrations (apenas no container web/reverb)
# ---------------------------------------------------------------------------
if [ "${CONTAINER_ROLE:-web}" = "web" ]; then
    log "Executando migrations..."
    php artisan migrate --force --no-interaction
fi

# ---------------------------------------------------------------------------
# 6) Permissões
# ---------------------------------------------------------------------------
HOST_UID=$(stat -c '%u' "$APP_DIR" 2>/dev/null || echo 0)
if [ "$HOST_UID" != "0" ] && [ "$HOST_UID" != "$(id -u www-data)" ]; then
    usermod -u "$HOST_UID" www-data 2>/dev/null || true
fi

mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/testing storage/framework/views storage/logs bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache
chmod -R ug+rwX storage bootstrap/cache

log "Inicialização concluída. Iniciando supervisor (nginx + php-fpm)..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
