#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="${INFRA_ROOT:-/infra-deploy}"

if [[ -n "${APP_SLUG:-}" && -f "${INFRA_ROOT}/ci/apps/${APP_SLUG}.sh" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${INFRA_ROOT}/ci/apps/${APP_SLUG}.sh"
  set +a
  if [[ -n "${APP_GIT_SUBDIR:-}" ]]; then
    export NOTIFY_APP_GIT_SUBDIR="${APP_GIT_SUBDIR}"
  fi
fi

if [[ -z "${N8N_DEPLOY_WEBHOOK_URL:-}" && -f "${INFRA_ROOT}/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${INFRA_ROOT}/.env" || true
  set +a
fi

if [[ -z "${N8N_DEPLOY_WEBHOOK_URL:-}" && -n "${N8N_API_URL:-}" ]]; then
  N8N_DEPLOY_WEBHOOK_URL="${N8N_API_URL%/}/webhook/jenkins-deploy-notify"
  export N8N_DEPLOY_WEBHOOK_URL
fi

if [[ -z "${N8N_DEPLOY_WEBHOOK_URL:-}" ]]; then
  echo "notify-n8n-deploy: N8N_DEPLOY_WEBHOOK_URL ou N8N_API_URL não definido; notificação ignorada." >&2
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "notify-n8n-deploy: python3 não encontrado no agente; instale python3 na imagem Jenkins ou no host." >&2
  exit 0
fi

exec python3 "${SCRIPT_DIR}/notify_n8n_deploy.py" "$@"
