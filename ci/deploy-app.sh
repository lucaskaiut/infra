#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SLUG="${1:-}"

usage() {
  echo "Uso: $0 <app-slug>" >&2
  echo "Configurações em ${ROOT}/ci/apps/<slug>.sh (ex.: ematricula)." >&2
  exit 1
}

[[ -n "$SLUG" ]] || usage

if [[ ! "$SLUG" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Slug inválido: apenas a-z, 0-9 e hífen; deve começar por letra." >&2
  exit 1
fi

CFG="${ROOT}/ci/apps/${SLUG}.sh"
if [[ ! -f "$CFG" ]]; then
  echo "Configuração em falta: $CFG" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CFG"

[[ -n "${APP_COMPOSE_DIR:-}" ]] || {
  echo "APP_COMPOSE_DIR tem de estar definido em $CFG" >&2
  exit 1
}

STACK="${ROOT}/${APP_COMPOSE_DIR}"
[[ -d "$STACK" ]] || {
  echo "Pasta da stack inexistente: $STACK" >&2
  exit 1
}

PROBE_FINALIZED=0
PROBE_LOG=""
PROBE_PID=""

finalize_probe_report() {
  if [[ "${PROBE_FINALIZED}" == 1 ]]; then
    return 0
  fi
  if [[ -z "${PROBE_PID:-}" && -z "${PROBE_LOG:-}" ]]; then
    return 0
  fi
  PROBE_FINALIZED=1
  if [[ -n "${PROBE_PID:-}" ]] && kill -0 "${PROBE_PID}" 2>/dev/null; then
    kill "${PROBE_PID}" 2>/dev/null || true
    wait "${PROBE_PID}" 2>/dev/null || true
  fi
  if [[ -n "${PROBE_LOG}" && -f "${PROBE_LOG}" ]]; then
    echo "--- HTTP probe durante deploy (${APP_HTTP_PROBE_URL:-}) ---"
    total=$(wc -l <"${PROBE_LOG}" | tr -d ' ')
    echo "Amostras: ${total}"
    awk '{c[$2]++} END {for (k in c) print k, c[k]}' "${PROBE_LOG}" | sort -k2 -nr
    echo "Últimas linhas:"
    tail -n 15 "${PROBE_LOG}"
    rm -f "${PROBE_LOG}"
  fi
}

cd "$STACK"

if [[ -n "${APP_HTTP_PROBE_SERVICE_HOST:-}" && -f .env ]]; then
  DOMAIN_VAL=$(grep -E '^DOMAIN=' .env | head -1 | cut -d= -f2- | tr -d '\r' | sed 's/^["'\'']//;s/["'\'']$//')
  if [[ -n "$DOMAIN_VAL" ]]; then
    APP_HTTP_PROBE_URL="https://${APP_HTTP_PROBE_SERVICE_HOST}.${DOMAIN_VAL}/up"
    PROBE_LOG=$(mktemp)
    "${ROOT}/ci/http-probe-loop.sh" "$APP_HTTP_PROBE_URL" "$PROBE_LOG" &
    PROBE_PID=$!
    trap 'finalize_probe_report' EXIT
  fi
fi

if [[ -n "${APP_GIT_SUBDIR:-}" && -n "${APP_GIT_REMOTE:-}" ]]; then
  SUB="${STACK}/${APP_GIT_SUBDIR}"
  BR="${APP_GIT_BRANCH:-main}"
  if [[ ! -d "$SUB/.git" ]]; then
    git clone --branch "$BR" --single-branch --depth 1 "$APP_GIT_REMOTE" "$SUB"
  else
    git -C "$SUB" fetch origin "$BR"
    git -C "$SUB" pull --ff-only origin "$BR"
  fi
fi

COMPOSE_LOCAL=()
if [[ -f docker-compose.yml ]]; then
  COMPOSE_LOCAL=(-f docker-compose.yml)
fi

if [[ ${#COMPOSE_LOCAL[@]} -gt 0 ]]; then
  docker compose "${COMPOSE_LOCAL[@]}" build
else
  docker compose build
fi

SWARM_DONE=0
if [[ "${APP_USE_SWARM:-0}" == 1 ]]; then
  SWARM_FILE="${APP_SWARM_COMPOSE_FILE:-docker-stack.yml}"
  STACK_NAME="${APP_SWARM_STACK_NAME:?defina APP_SWARM_STACK_NAME em ci/apps/<slug>.sh quando APP_USE_SWARM=1}"
  [[ -f "$SWARM_FILE" ]] || {
    echo "Ficheiro Swarm inexistente: ${STACK}/$SWARM_FILE" >&2
    exit 1
  }
  if ! docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null | grep -q true; then
    echo "Docker Swarm inativo. Na VPS: SWARM_ADVERTISE_ADDR=<IP> ${ROOT}/ci/swarm-bootstrap.sh" >&2
    exit 1
  fi
  RENDERED=$(mktemp)
  docker compose -f "$SWARM_FILE" --env-file .env config >"$RENDERED"
  docker stack deploy -c "$RENDERED" "$STACK_NAME"
  rm -f "$RENDERED"
  SWARM_DONE=1
else
  compose_scale_args=()
  if [[ -n "${APP_COMPOSE_SCALES:-}" ]]; then
    IFS=',' read -ra _scale_pairs <<<"${APP_COMPOSE_SCALES// /}"
    for _sp in "${_scale_pairs[@]}"; do
      [[ -n "$_sp" ]] && compose_scale_args+=(--scale "$_sp")
    done
  fi

  if [[ ${#compose_scale_args[@]} -gt 0 ]]; then
    if docker compose "${COMPOSE_LOCAL[@]}" up -d --help 2>&1 | grep -q '[[:space:]]--wait[[:space:]]'; then
      docker compose "${COMPOSE_LOCAL[@]}" up -d "${compose_scale_args[@]}" --wait || docker compose "${COMPOSE_LOCAL[@]}" up -d "${compose_scale_args[@]}"
    else
      docker compose "${COMPOSE_LOCAL[@]}" up -d "${compose_scale_args[@]}"
    fi
  else
    if docker compose "${COMPOSE_LOCAL[@]}" up -d --help 2>&1 | grep -q '[[:space:]]--wait[[:space:]]'; then
      docker compose "${COMPOSE_LOCAL[@]}" up -d --wait || docker compose "${COMPOSE_LOCAL[@]}" up -d
    else
      docker compose "${COMPOSE_LOCAL[@]}" up -d
    fi
  fi
fi

finalize_probe_report
trap - EXIT

if [[ "$SWARM_DONE" == 1 ]]; then
  docker stack ps "${APP_SWARM_STACK_NAME}" --no-trunc 2>/dev/null || true
else
  docker compose "${COMPOSE_LOCAL[@]}" ps
fi
