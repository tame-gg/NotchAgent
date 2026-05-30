#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"

legacy_brand='code''island'

content_hits="$(rg --hidden -n -i "$legacy_brand" . \
  -g '!/.git/**' \
  -g '!/.build/**' \
  -g '!/.superpowers/**' \
  -g '!Package.resolved' || true)"

path_hits="$(find . \
  \( -path './.git' -o -path './.build' -o -path './.superpowers' \) -prune \
  -o -iname "*${legacy_brand}*" -print)"

if [[ -n "$content_hits" || -n "$path_hits" ]]; then
  if [[ -n "$content_hits" ]]; then
    echo "$content_hits"
  fi
  if [[ -n "$path_hits" ]]; then
    echo "$path_hits"
  fi
  exit 1
fi

echo "no legacy brand mentions remain"
