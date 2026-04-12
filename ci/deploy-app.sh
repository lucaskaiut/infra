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

cd "$STACK"

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

docker compose build
if docker compose up -d --help 2>&1 | grep -q '[[:space:]]--wait[[:space:]]'; then
  docker compose up -d --wait || docker compose up -d
else
  docker compose up -d
fi
docker compose ps
