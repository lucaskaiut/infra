#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${ROOT}/.env" ]]; then
  # shellcheck source=/dev/null
  source "${ROOT}/.env"
fi

REMOTE="${1:?uso: $0 <git-remote-url> <before-sha> <after-sha> [path-prefix]}"
BEFORE="${2:?}"
AFTER="${3:?}"
PREFIX="${4:-api}"

build_git_remote_with_auth() {
  local remote="${1:-}"
  if [[ -z "$remote" ]]; then
    return 0
  fi
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    printf '%s\n' "$remote"
    return 0
  fi
  if [[ ! "$remote" =~ ^https://github\.com/ ]]; then
    printf '%s\n' "$remote"
    return 0
  fi

  local username="${GITHUB_USERNAME:-git}"
  local encoded_user encoded_token path
  encoded_user=$(printf '%s' "$username" | sed 's/%/%25/g; s/:/%3A/g; s/@/%40/g')
  encoded_token=$(printf '%s' "$GITHUB_TOKEN" | sed 's/%/%25/g; s/:/%3A/g; s/@/%40/g')
  path="${remote#https://}"
  printf 'https://%s:%s@%s\n' "$encoded_user" "$encoded_token" "$path"
}

REMOTE="$(build_git_remote_with_auth "$REMOTE")"

if [[ "$AFTER" =~ ^0+$ ]]; then
  echo "After é zero (branch apagada ou evento sem novo HEAD); sem deploy." >&2
  exit 1
fi

if [[ "$BEFORE" == "$AFTER" ]]; then
  echo "Before e after iguais; sem deploy." >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir "$TMP/r"
cd "$TMP/r"
git init --quiet
git remote add origin "$REMOTE"

git -c protocol.version=2 fetch --quiet --no-tags --depth=2048 origin "$AFTER"
git -c protocol.version=2 fetch --quiet --no-tags --depth=2048 origin "$BEFORE" || true

if ! git cat-file -e "${BEFORE}^{commit}" 2>/dev/null || ! git cat-file -e "${AFTER}^{commit}" 2>/dev/null; then
  echo "Não foi possível obter os commits before/after (histórico profundo ou SHAs inválidos)." >&2
  exit 2
fi

mapfile -t changed < <(git diff --name-only "$BEFORE" "$AFTER")
if [[ ${#changed[@]} -eq 0 ]]; then
  echo "Diff vazio entre before e after; sem deploy." >&2
  exit 1
fi

for p in "${changed[@]}"; do
  if [[ "$p" == "$PREFIX" || "$p" == "${PREFIX}/"* ]]; then
    exit 0
  fi
done

echo "Nenhuma alteração sob ${PREFIX}/ neste intervalo; deploy não necessário." >&2
exit 1
