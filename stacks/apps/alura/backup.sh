#!/usr/bin/env bash
# =============================================================================
# Alura Backup Script
# Faz dump do MySQL + OpenSearch + storage, compacta, envia para Cloudflare R2
# e remove arquivos locais com mais de 24h.
#
# Uso: ./backup.sh [/caminho/para/backup.env]
# Sem argumento, lê o .env ao lado do script.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="/var/backups/alura"
RETENTION_HOURS=24
TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
BACKUP_DIR=""
LOG_FILE=""

# Garante que rclone está no PATH (instalado em ~/.local/bin)
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Carrega .env (primeiro argumento ou .env ao lado do script)
# ---------------------------------------------------------------------------
ENV_FILE="${1:-${SCRIPT_DIR}/.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

# Aplica defaults após carregar .env
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/alura}"
RETENTION_HOURS="${RETENTION_HOURS:-24}"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
LOG_FILE="${BACKUP_ROOT}/backup.log"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
die()  { log "[ERRO] $*"; exit 1; }

# ---------------------------------------------------------------------------
# Validação de variáveis obrigatórias
# ---------------------------------------------------------------------------
check_var() {
  local name="$1" val="${!1:-}"
  if [[ -z "$val" ]]; then
    echo "[ERRO] Variável obrigatória não definida: $name" | tee -a "$LOG_FILE"
    return 1
  fi
}

# R2 (validado sob demanda no passo 5 — opcional)
# R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT, R2_BUCKET

# MySQL
MYSQL_CONTAINER="${MYSQL_CONTAINER:-infra-shared_mysql.1.$(docker service ps infra-shared_mysql -q --no-trunc 2>/dev/null | head -1)}"
MYSQL_DATABASE="${MYSQL_DATABASE:-alura}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"

# OpenSearch
OPENSEARCH_CONTAINER="${OPENSEARCH_CONTAINER:-infra-opensearch_opensearch.1.$(docker service ps infra-opensearch_opensearch -q --no-trunc 2>/dev/null | head -1)}"
OPENSEARCH_INDEX="${OPENSEARCH_INDEX:-products}"
OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"

# Alura app (para storage)
ALURA_APP_CONTAINER="${ALURA_APP_CONTAINER:-infra-app-alura_app.1.$(docker service ps infra-app-alura_app -q --no-trunc 2>/dev/null | head -1)}"
ALURA_STORAGE_PATH="${ALURA_STORAGE_PATH:-/var/www/html/storage/app}"

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR" "$BACKUP_ROOT"
log "Iniciando backup em $BACKUP_DIR"

# ---------------------------------------------------------------------------
# 1. MySQL dump
# ---------------------------------------------------------------------------
log "1/4 MySQL dump (banco: $MYSQL_DATABASE)..."

# Se MYSQL_PASSWORD não foi definida no .env, extrai do container em runtime
if [[ -z "$MYSQL_PASSWORD" ]]; then
  MYSQL_PASSWORD=$(docker inspect "$MYSQL_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null \
    | grep '^MYSQL_ROOT_PASSWORD=' | cut -d= -f2-)
  if [[ -z "$MYSQL_PASSWORD" ]]; then
    die "MYSQL_PASSWORD não definida e não foi possível extrair do container"
  fi
  log "   MySQL password extraída do container em runtime"
fi

docker exec "$MYSQL_CONTAINER" \
  mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --hex-blob \
  "$MYSQL_DATABASE" \
  > "$BACKUP_DIR/mysql_${MYSQL_DATABASE}.sql" \
  || die "Falha no mysqldump"

log "   MySQL dump: $(du -h "$BACKUP_DIR/mysql_${MYSQL_DATABASE}.sql" | cut -f1)"

# ---------------------------------------------------------------------------
# 2. OpenSearch snapshot (exporta documentos como JSON linha-a-linha)
# ---------------------------------------------------------------------------
log "2/4 OpenSearch dump (índice: $OPENSEARCH_INDEX)..."

# Usa scroll API para exportar todos os documentos
SCROLL_SIZE=1000
SCROLL="5m"
ES_FILE="$BACKUP_DIR/opensearch_${OPENSEARCH_INDEX}.jsonl"

# Primeira busca
SCROLL_RESPONSE=$(docker exec "$OPENSEARCH_CONTAINER" curl -s \
  "$OPENSEARCH_URL/${OPENSEARCH_INDEX}/_search?scroll=${SCROLL}&size=${SCROLL_SIZE}" \
  -H 'Content-Type: application/json' \
  -d '{"query":{"match_all":{}}}' 2>/dev/null) || true

if [[ -z "$SCROLL_RESPONSE" || "$SCROLL_RESPONSE" == "null" ]]; then
  log "   OpenSearch: índice vazio ou inacessível — pulando"
else
  SCROLL_ID=$(echo "$SCROLL_RESPONSE" | jq -r '._scroll_id // empty')
  HITS=$(echo "$SCROLL_RESPONSE" | jq -r '.hits.hits[]?._source' 2>/dev/null)

  if [[ -n "$HITS" ]]; then
    echo "$HITS" >> "$ES_FILE"
    COUNT=$(echo "$SCROLL_RESPONSE" | jq -r '.hits.total.value // .hits.total // 0')

    # Continua scroll enquanto houver documentos
    while [[ -n "$SCROLL_ID" ]]; do
      SCROLL_RESPONSE=$(docker exec "$OPENSEARCH_CONTAINER" curl -s \
        "$OPENSEARCH_URL/_search/scroll" \
        -H 'Content-Type: application/json' \
        -d "{\"scroll\":\"${SCROLL}\",\"scroll_id\":\"${SCROLL_ID}\"}" 2>/dev/null) || break

      SCROLL_ID=$(echo "$SCROLL_RESPONSE" | jq -r '._scroll_id // empty')
      MORE_HITS=$(echo "$SCROLL_RESPONSE" | jq -r '.hits.hits[]?._source' 2>/dev/null)

      if [[ -z "$MORE_HITS" || "$MORE_HITS" == "null" ]]; then
        break
      fi
      echo "$MORE_HITS" >> "$ES_FILE"
    done

    # Limpa o scroll
    [[ -n "$SCROLL_ID" ]] && docker exec "$OPENSEARCH_CONTAINER" curl -s -X DELETE \
      "$OPENSEARCH_URL/_search/scroll" \
      -H 'Content-Type: application/json' \
      -d "{\"scroll_id\":\"${SCROLL_ID}\"}" >/dev/null 2>&1 || true

    log "   OpenSearch: ${COUNT} documentos exportados ($(du -h "$ES_FILE" | cut -f1))"
  else
    log "   OpenSearch: índice vazio — pulando"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Storage (arquivos de upload)
# ---------------------------------------------------------------------------
log "3/4 Storage (container: $ALURA_APP_CONTAINER)..."

STORAGE_FILE="$BACKUP_DIR/storage.tar.gz"
if docker exec "$ALURA_APP_CONTAINER" test -d "$ALURA_STORAGE_PATH" 2>/dev/null; then
  docker exec "$ALURA_APP_CONTAINER" tar czf - -C "$(dirname "$ALURA_STORAGE_PATH")" "$(basename "$ALURA_STORAGE_PATH")" \
    > "$STORAGE_FILE" \
    || die "Falha ao copiar storage"

  if [[ -s "$STORAGE_FILE" ]]; then
    log "   Storage: $(du -h "$STORAGE_FILE" | cut -f1)"
  else
    rm -f "$STORAGE_FILE"
    log "   Storage: vazio — pulando"
  fi
else
  log "   Storage: diretório não encontrado — pulando"
fi

# ---------------------------------------------------------------------------
# 4. Compactar
# ---------------------------------------------------------------------------
log "4/5 Compactando..."

ARCHIVE_NAME="alura_backup_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_ROOT}/${ARCHIVE_NAME}"

tar czf "$ARCHIVE_PATH" -C "$BACKUP_DIR" . \
  || die "Falha ao criar arquivo compactado"

log "   Arquivo: $ARCHIVE_NAME ($(du -h "$ARCHIVE_PATH" | cut -f1))"

# ---------------------------------------------------------------------------
# 5. Upload para R2 (opcional — pula se credenciais não definidas)
# ---------------------------------------------------------------------------
R2_OK=true
for var in R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ENDPOINT R2_BUCKET; do
  if ! check_var "$var"; then R2_OK=false; fi
done

if $R2_OK && command -v rclone &>/dev/null; then
  log "5/5 Enviando para R2..."

  # Upload para R2 via rclone
  export RCLONE_CONFIG_S3_TYPE=s3
  export RCLONE_CONFIG_S3_PROVIDER=Cloudflare
  export RCLONE_CONFIG_S3_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
  export RCLONE_CONFIG_S3_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
  export RCLONE_CONFIG_S3_ENDPOINT="$R2_ENDPOINT"
  export RCLONE_CONFIG_S3_ACL=private

  if rclone copyto "$ARCHIVE_PATH" "s3:${R2_BUCKET}/alura/${ARCHIVE_NAME}" \
      --s3-no-check-bucket \
      --progress 2>&1 | tail -5; then
    log "   Upload R2: OK"
  else
    die "Falha no upload para R2"
  fi
else
  log "5/5 Upload R2: pulado (credenciais não configuradas ou rclone indisponível)"
fi

# ---------------------------------------------------------------------------
# Cleanup: remove diretório temporário e backups locais > RETENTION_HOURS
# ---------------------------------------------------------------------------
rm -rf "$BACKUP_DIR"
log "Limpeza: removendo backups com mais de ${RETENTION_HOURS}h..."

find "$BACKUP_ROOT" -maxdepth 1 -name 'alura_backup_*.tar.gz' -mmin "+$((RETENTION_HOURS * 60))" -print -delete \
  | while read -r f; do log "   Removido: $f"; done

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log "Backup concluído com sucesso: $ARCHIVE_NAME"

# Reporta tamanho total dos backups locais restantes
LOCAL_COUNT=$(find "$BACKUP_ROOT" -maxdepth 1 -name 'alura_backup_*.tar.gz' | wc -l)
LOCAL_SIZE=$(du -sh "$BACKUP_ROOT" 2>/dev/null | cut -f1)
log "Backups locais: ${LOCAL_COUNT} arquivos, ${LOCAL_SIZE}"
