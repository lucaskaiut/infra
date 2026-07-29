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
# 3) Dump autoload com scripts (package:discover)
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
# 5) Aguarda MySQL
# ---------------------------------------------------------------------------
env_get() {
    local key="$1" default="${2:-}" value
    value="$(grep -E "^${key}=" .env | tail -n1 | cut -d '=' -f2- | tr -d '"' | tr -d "'" || true)"
    echo "${value:-$default}"
}
DB_HOST_VAL="$(env_get DB_HOST mysql)"
DB_PORT_VAL="$(env_get DB_PORT 3306)"
DB_DATABASE_VAL="$(env_get DB_DATABASE chat_one)"
DB_USERNAME_VAL="$(env_get DB_USERNAME chatone)"
DB_PASSWORD_VAL="$(env_get DB_PASSWORD "")"
export DB_HOST_VAL DB_PORT_VAL DB_DATABASE_VAL DB_USERNAME_VAL DB_PASSWORD_VAL

log "Aguardando MySQL em ${DB_HOST_VAL}:${DB_PORT_VAL}..."
tries=0
until php -r '
    try {
        $pdo = new PDO(
            "mysql:host=" . getenv("DB_HOST_VAL") . ";port=*** . getenv("DB_PORT_VAL") . ";dbname=*** . getenv("DB_DATABASE_VAL"),
            getenv("DB_USERNAME_VAL"),
            getenv("DB_PASSWORD_VAL"),
            [PDO::ATTR_TIMEOUT => 3]
        );
        exit(0);
    } catch (Throwable $e) {
        exit(1);
    }
' 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -ge 90 ]; then
        log "ERRO: MySQL indisponível após ${tries} tentativas"
        exit 1
    fi
    sleep 2
done
log "MySQL disponível"

# ---------------------------------------------------------------------------
# 6) Cache otimizado de produção
# ---------------------------------------------------------------------------
log "Otimizando caches..."
php artisan config:cache --no-interaction || true
php artisan route:cache --no-interaction || true
php artisan view:cache --no-interaction || true
php artisan event:cache --no-interaction || true

# ---------------------------------------------------------------------------
# 7) Migrations (apenas no container web)
# ---------------------------------------------------------------------------
if [ "${CONTAINER_ROLE:-web}" = "web" ]; then
    log "Executando migrations..."
    php artisan migrate --force --no-interaction
fi

# ---------------------------------------------------------------------------
# 8) Permissões
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
