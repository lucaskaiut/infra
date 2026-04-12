#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null | grep -q true; then
  echo "Swarm já ativo neste daemon."
else
  ADV="${SWARM_ADVERTISE_ADDR:-}"
  if [[ -z "$ADV" ]]; then
    echo "Swarm inativo. Defina SWARM_ADVERTISE_ADDR (IP público ou privado da VPS) e volte a correr:" >&2
    echo "  SWARM_ADVERTISE_ADDR=203.0.113.10 $0" >&2
    exit 1
  fi
  docker swarm init --advertise-addr "$ADV"
fi

create_overlay() {
  local n="$1"
  if docker network inspect "$n" &>/dev/null; then
    local driver
    driver=$(docker network inspect "$n" --format '{{.Driver}}')
    if [[ "$driver" != "overlay" ]]; then
      echo "Rede $n já existe com driver $driver (esperado overlay)." >&2
      echo "Migração: parar stacks que usam $n, remover a rede bridge antiga e voltar a correr este script. Ver docs/arquitetura.md (Docker Swarm)." >&2
      exit 1
    fi
    echo "Rede overlay $n já existe."
  else
    docker network create -d overlay --attachable "$n"
    echo "Criada rede overlay --attachable $n"
  fi
}

create_overlay infra_edge
create_overlay infra_shared

echo "Pronto. Seguir docs/arquitetura.md para stack deploy (edge, shared, apps)."
