#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT}/.env"
WF_JSON="${ROOT}/ci/n8n/workflows/jenkins-deploy-notify.json"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Falta ${ENV_FILE} com N8N_API_URL e N8N_API_KEY." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

if [[ -z "${N8N_API_URL:-}" || -z "${N8N_API_KEY:-}" ]]; then
  echo "Define N8N_API_URL e N8N_API_KEY no .env da raiz do repo." >&2
  exit 1
fi

BASE="${N8N_API_URL%/}"
API="${BASE}/api/v1"

WF_NAME=$(python3 -c "import json; print(json.load(open('${WF_JSON}'))['name'])" 2>/dev/null || echo "")

list_tmp=$(mktemp)
create_resp=$(mktemp)
trap 'rm -f "${list_tmp}" "${create_resp}"' EXIT

curl -sS -o "${list_tmp}" "${API}/workflows?limit=250" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "accept: application/json" || true

wid=$(python3 <<PY
import json
name = """${WF_NAME}"""
with open("${list_tmp}") as f:
    data = json.load(f)
for row in data.get("data", []):
    if row.get("name") == name:
        print(row.get("id", ""))
        break
PY
)

if [[ -z "$wid" ]]; then
  http=$(curl -sS -o "${create_resp}" -w '%{http_code}' -X POST "${API}/workflows" \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -H "Content-Type: application/json" \
    -d @"${WF_JSON}") || true

  if [[ "$http" != "200" && "$http" != "201" ]]; then
    echo "POST /workflows falhou (HTTP ${http}). Corpo:" >&2
    cat "${create_resp}" >&2
    exit 1
  fi

  wid=$(python3 -c "import json; d=json.load(open('${create_resp}')); print(d.get('id',''))" 2>/dev/null || true)
else
  echo "Workflow já existe (id=${wid}); a saltar criação."
fi
if [[ -z "$wid" ]]; then
  echo "Resposta sem id de workflow." >&2
  [[ -s "${create_resp}" ]] && cat "${create_resp}" >&2
  exit 1
fi

act_http=$(curl -sS -o /dev/null -w '%{http_code}' -X POST "${API}/workflows/${wid}/activate" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{}') || true

if [[ "$act_http" != "200" ]]; then
  echo "AVISO: POST .../activate devolveu HTTP ${act_http}. Publica manualmente no n8n se necessário." >&2
fi

WEBHOOK_PATH=$(python3 -c "import json; d=json.load(open('${WF_JSON}')); \
  n=[x for x in d['nodes'] if x['type']=='n8n-nodes-base.webhook'][0]; \
  print(n['parameters'].get('path',''))" 2>/dev/null)

echo "Workflow criado e ativado (id=${wid})."
echo "URL de produção (n8n 2.x usa só o path, sem UUID no URL):"
echo "  POST ${BASE}/webhook/${WEBHOOK_PATH}"
echo "Payload de exemplo: ci/n8n/examples/jenkins-deploy-notify.payload.json"
echo "Jenkins (exemplo):"
echo "  curl -sS -X POST \"${BASE}/webhook/${WEBHOOK_PATH}\" \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d @ci/n8n/examples/jenkins-deploy-notify.payload.json"
