#!/usr/bin/env bash
set -uo pipefail
URL="${1:?URL}"
LOG="${2:?log file}"
: >"$LOG"
while true; do
  c="000"
  if out=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$URL" 2>/dev/null); then
    c="$out"
  fi
  echo "$(date -Iseconds) $c" >>"$LOG"
  sleep 0.2
done
