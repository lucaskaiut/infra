#!/usr/bin/env bash
# =============================================================================
# Vulcano Backup Script
# Faz dump do MySQL + storage, compacta, envia para Cloudflare R2
# e remove arquivos locais com mais de 24h.
#
# Uso: ./backup.sh [/caminho/para/backup.env]
# Sem argumento, lê o .env ao lado do script.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="/home/kaiut/backups/chatone"
RETENTION_HOURS=24
TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
BACKUP_DIR=""
LOG_FILE=""

export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Carrega .env (primeiro argumento ou .env ao lado do script)
# ---------------------------------------------------------------------------
ENV_FILE="${1:-${SCRIPT_DIR}/.env}"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# Aplica defaults após carregar .env
BACKUP_ROOT="${BACKUP_ROOT:-/home/kaiut/backups/chatone}"
RETENTION_HOURS="${RETENTION_HOURS:-24}"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
LOG_FILE="${BACKUP_ROOT}/backup.log"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
die()  { log "[ERRO] $*"; exit 1; }

check_var() {
  local name="$1" val="${!1:-}"
  if [[ -z "$val" ]]; then
    echo "[ERRO] Variável obrigatória não definida: $name" | tee -a "$LOG_FILE"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Configuração (sobrescrevível via .env)
# ---------------------------------------------------------------------------

# MySQL
MYSQL_CONTAINER="${MYSQL_CONTAINER:-infra-shared_mysql.1.$(docker service ps infra-shared_mysql -q --no-trunc 2>/dev/null | head -1)}"
MYSQL_DATABASE="${MYSQL_DATABASE:-chat_one}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD=
# App (para storage)
APP_CONTAINER="${APP_CONTAINER:-infra-app-chat-one_app.1.$(docker service ps infra-app-chat-one_app -q --no-trunc 2>/dev/null | head -1)}"
APP_STORAGE_PATH="${APP_STORAGE_PATH:-/var/www/html/storage/app}"

# R2 (validado sob demanda — opcional)
# R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_ENDPOINT, R2_BUCKET

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR" "$BACKUP_ROOT"
log "Iniciando backup em $BACKUP_DIR"

# ===========================================================================
# 1. MySQL dump
# ===========================================================================
log "1/4 MySQL dump (banco: $MYSQL_DATABASE)..."

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

# ===========================================================================
# 2. Storage (arquivos de upload — volume persistente)
# ===========================================================================
log "2/4 Storage (container: $APP_CONTAINER)..."

STORAGE_FILE="$BACKUP_DIR/storage.tar.gz"
if docker exec "$APP_CONTAINER" test -d "$APP_STORAGE_PATH" 2>/dev/null; then
  docker exec "$APP_CONTAINER" tar czf - -C "$(dirname "$APP_STORAGE_PATH")" "$(basename "$APP_STORAGE_PATH")" \
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

# ===========================================================================
# 3. Compactar
# ===========================================================================
log "3/4 Compactando..."

ARCHIVE_NAME="chatone_backup_${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_ROOT}/${ARCHIVE_NAME}"

tar czf "$ARCHIVE_PATH" -C "$BACKUP_DIR" . \
  || die "Falha ao criar arquivo compactado"

log "   Arquivo: $ARCHIVE_NAME ($(du -h "$ARCHIVE_PATH" | cut -f1))"

# ===========================================================================
# 4. Upload para R2 + limpeza de arquivos antigos no bucket
# ===========================================================================
R2_OK=true
for var in R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ENDPOINT R2_BUCKET; do
  if ! check_var "$var"; then R2_OK=false; fi
done

if $R2_OK && command -v rclone &>/dev/null; then
  log "4/5 Enviando para R2..."

  export RCLONE_CONFIG_S3_TYPE=s3
  export RCLONE_CONFIG_S3_PROVIDER=Cloudflare
  export RCLONE_CONFIG_S3_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
  export RCLONE_CONFIG_S3_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
  export RCLONE_CONFIG_S3_ENDPOINT="$R2_ENDPOINT"
  export RCLONE_CONFIG_S3_ACL=private

  if rclone copyto "$ARCHIVE_PATH" "s3:${R2_BUCKET}/chatone/${ARCHIVE_NAME}" \
      --s3-no-check-bucket \
      --progress 2>&1 | tail -5; then
    log "   Upload R2: OK"
  else
    die "Falha no upload para R2"
  fi

  log "5/5 Limpando arquivos antigos no R2 (>${RETENTION_HOURS}h)..."

  # Lista arquivos que seriam removidos (dry-run) para log
  # Trailing slash é obrigatório: sem ele o rclone trata como single file e rejeita --min-age
  TO_DELETE=$(rclone delete "s3:${R2_BUCKET}/chatone/" \
    --s3-no-check-bucket \
    --min-age "${RETENTION_HOURS}h" \
    --dry-run 2>&1)
  if [[ -n "$TO_DELETE" ]]; then
    echo "$TO_DELETE" | while read -r f; do [[ -n "$f" ]] && log "   [dry-run] Removeria: $f"; done

    # Delete real — sem grep, as linhas NOTICE do rclone são os arquivos removidos
    rclone delete "s3:${R2_BUCKET}/chatone/" \
      --s3-no-check-bucket \
      --min-age "${RETENTION_HOURS}h" 2>&1 \
      | while read -r f; do [[ -n "$f" ]] && log "   Removido R2: $f"; done
    log "   Limpeza R2: concluída"
  else
    log "   Limpeza R2: nada a remover"
  fi
else
  log "4/5 Upload R2: pulado (credenciais não configuradas ou rclone indisponível)"
  log "5/5 Limpeza R2: pulada"
fi

# ===========================================================================
# Cleanup: remove diretório temporário e backups locais > RETENTION_HOURS
# ===========================================================================
rm -rf "$BACKUP_DIR"
log "Limpeza: removendo backups com mais de ${RETENTION_HOURS}h..."

find "$BACKUP_ROOT" -maxdepth 1 -name 'chatone_backup_*.tar.gz' -mmin "+$((RETENTION_HOURS * 60))" -print -delete \
  | while read -r f; do log "   Removido: $f"; done

# ===========================================================================
# Done
# ===========================================================================
log "Backup concluído com sucesso: $ARCHIVE_NAME"

LOCAL_COUNT=$(find "$BACKUP_ROOT" -maxdepth 1 -name 'chatone_backup_*.tar.gz' | wc -l)
LOCAL_SIZE=$(du -sh "$BACKUP_ROOT" 2>/dev/null | cut -f1)
log "Backups locais: ${LOCAL_COUNT} arquivos, ${LOCAL_SIZE}"
