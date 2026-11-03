#!/usr/bin/env bash
# Atelier J3 — mesure la répartition v1/v2 vue par un client : N requêtes sur /api/version.
# Usage : ./watch-split.sh [URL] [N]      ex. ./watch-split.sh http://skyboard.local:8081/api/version 100
URL="${1:-http://skyboard.local:8081/api/version}"
N="${2:-100}"
while true; do
  v1=0; v2=0; err=0
  for _ in $(seq "$N"); do
    out=$(curl -s --max-time 2 "$URL" || true)
    case "$out" in
      *'"version":"v1"'*) v1=$((v1+1));;
      *'"version":"v2"'*) v2=$((v2+1));;
      *) err=$((err+1));;
    esac
  done
  printf '%s  v1: %3d  v2: %3d  erreurs: %3d   (%d requêtes)\n' "$(date +%T)" "$v1" "$v2" "$err" "$N"
done
