1|#!/bin/sh
2|set -e
3|
4|APP_DIR="/var/www/html"
5|cd "$APP_DIR"
6|
7|log() { echo "[chat-one] $*"; }
8|
9|# ---------------------------------------------------------------------------
10|# 1) .env a partir de .env.example (se não existir)
11|# ---------------------------------------------------------------------------
12|if [ ! -f .env ]; then
13|    if [ -f .env.example ]; then
14|        cp .env.example .env
15|        log ".env criado a partir de .env.example"
16|    fi
17|fi
18|
19|# ---------------------------------------------------------------------------
20|# 2) APP_KEY (apenas se vazia)
21|# ---------------------------------------------------------------------------
22|if ! grep -q '^APP_KEY=[^[:space:]]' .env 2>/dev/null || grep -q '^APP_KEY=$' .env 2>/dev/null; then
23|    log "APP_KEY vazia — gerando..."
24|    php artisan key:generate --force --no-interaction
25|fi
26|
27|# ---------------------------------------------------------------------------
28|# 3) Dump autoload com scripts (package:discover) — precisa do Redis disponível
29|# ---------------------------------------------------------------------------
30|if [ ! -f vendor/autoload.php ] || [ ! -f bootstrap/cache/packages.php ]; then
31|    log "Executando composer dump-autoload (package:discover)..."
32|    composer dump-autoload --no-interaction --optimize --classmap-authoritative
33|fi
34|
35|# ---------------------------------------------------------------------------
36|# 4) Storage link
37|# ---------------------------------------------------------------------------
38|if [ ! -e public/storage ]; then
39|    php artisan storage:link --no-interaction || log "AVISO: storage link falhou"
40|fi
41|
42|# ---------------------------------------------------------------------------
43|# 5) Aguarda MySQL
44|# ---------------------------------------------------------------------------
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
56|
57|log "Aguardando MySQL em ${DB_HOST_VAL}:${DB_PORT_VAL}..."
58|tries=0
59|until php -r '
60|    try {
61|        $pdo = new PDO(
62|            "mysql:host=" . getenv("DB_HOST_VAL") . ";port=" . getenv("DB_PORT_VAL") . ";dbname=" . getenv("DB_DATABASE_VAL"),
63|            getenv("DB_USERNAME_VAL"),
64|            getenv("DB_PASSWORD_VAL"),
65|            [PDO::ATTR_TIMEOUT => 3]
66|        );
67|        exit(0);
68|    } catch (Throwable $e) {
69|        exit(1);
70|    }
71|' 2>/dev/null; do
72|    tries=$((tries + 1))
73|    if [ "$tries" -ge 90 ]; then
74|        log "ERRO: MySQL indisponível após ${tries} tentativas"
75|        exit 1
76|    fi
77|    sleep 2
78|done
79|log "MySQL disponível"
80|
81|# ---------------------------------------------------------------------------
82|# 6) Cache otimizado de produção
83|# ---------------------------------------------------------------------------
84|log "Otimizando caches..."
85|php artisan config:cache --no-interaction || true
86|php artisan route:cache --no-interaction || true
87|php artisan view:cache --no-interaction || true
88|php artisan event:cache --no-interaction || true
89|
90|# ---------------------------------------------------------------------------
91|# 7) Migrations (apenas no container web)
92|# ---------------------------------------------------------------------------
93|if [ "${CONTAINER_ROLE:-web}" = "web" ]; then
94|    log "Executando migrations..."
95|    php artisan migrate --force --no-interaction
96|fi
97|
98|# ---------------------------------------------------------------------------
99|# 6) Permissões
100|# ---------------------------------------------------------------------------
101|HOST_UID=$(stat -c '%u' "$APP_DIR" 2>/dev/null || echo 0)
102|if [ "$HOST_UID" != "0" ] && [ "$HOST_UID" != "$(id -u www-data)" ]; then
103|    usermod -u "$HOST_UID" www-data 2>/dev/null || true
104|fi
105|
106|mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/testing storage/framework/views storage/logs bootstrap/cache
107|chown -R www-data:www-data storage bootstrap/cache
108|chmod -R ug+rwX storage bootstrap/cache
109|
110|log "Inicialização concluída. Iniciando supervisor (nginx + php-fpm)..."
111|exec /usr/bin/supervisord -c /etc/supervisord.conf
112|