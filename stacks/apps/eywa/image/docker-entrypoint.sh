#!/bin/sh
set -e

APP_DIR="/var/www/html"
cd "$APP_DIR"
log() { echo "[eywa] $*"; }

# 1) .env (fallback: os valores reais vêm como variáveis de ambiente do stack)
if [ ! -f .env ] && [ -f .env.example ]; then
    cp .env.example .env
    log ".env criado a partir do .env.example"
fi

# 2) APP_KEY (normalmente já vem definida no .env do stack)
if ! grep -q '^APP_KEY=[^[:space:]]' .env 2>/dev/null && [ -z "${APP_KEY:-}" ]; then
    log "APP_KEY vazia - gerando..."
    php artisan key:generate --force --no-interaction
    export APP_KEY=$(grep '^APP_KEY=' .env | cut -d= -f2-)
fi

# 3) Autoload / cache de pacotes (a imagem de runtime não tem composer)
if [ ! -f vendor/autoload.php ]; then
    log "ERRO: vendor/autoload.php ausente na imagem"
    exit 1
fi
if [ ! -f bootstrap/cache/packages.php ]; then
    log "package:discover (cache de pacotes ausente)..."
    php artisan package:discover --ansi || log "AVISO: package:discover falhou"
fi

# 4) Storage link
if [ ! -e public/storage ]; then
    php artisan storage:link --no-interaction || true
fi

# 5) Aguarda MySQL
log "Aguardando MySQL..."
tries=0
while [ "$tries" -lt 90 ]; do
    if php -r '
        $h = getenv("DB_HOST") ?: "mysql";
        $p = getenv("DB_PORT") ?: "3306";
        $d = getenv("DB_DATABASE") ?: "eywa";
        $u = getenv("DB_USERNAME") ?: "eywa";
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

# 6) Cache (limpa antes de gerar; route:cache fica de fora porque há rota web com closure)
log "Otimizando caches..."
php artisan config:clear --no-interaction 2>/dev/null || true
php artisan route:clear --no-interaction 2>/dev/null || true
php artisan view:clear --no-interaction 2>/dev/null || true
php artisan event:clear --no-interaction 2>/dev/null || true
php artisan config:cache --no-interaction || { log "AVISO: config:cache falhou"; }
php artisan view:cache --no-interaction || true
php artisan event:cache --no-interaction || true

# 7) Migrations (apenas no papel web; tolera corrida entre réplicas)
if [ "${CONTAINER_ROLE:-web}" = "web" ]; then
    log "Executando migrations..."
    php artisan migrate --force --no-interaction || log "AVISO: migrations falharam (tabelas ja existem?)"
fi

# 8) Permissoes
mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
chmod -R ug+rwX storage bootstrap/cache 2>/dev/null || true

# 9) Papel do container
if [ $# -gt 0 ]; then
    log "Executando comando: $*"
    exec "$@"
fi

case "${CONTAINER_ROLE:-web}" in
    worker)
        log "Iniciando queue worker..."
        exec php artisan queue:work --sleep=1 --tries=3 --max-time=3600
        ;;
    scheduler)
        log "Iniciando scheduler..."
        exec php artisan schedule:work
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
