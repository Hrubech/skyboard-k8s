#!/usr/bin/env bash
# Atelier J3 — étape 1 : installation d'ingress-nginx via Helm (chart en cache local si pré-chargé J-1)
set -euo pipefail
cd "$(dirname "$0")"
CHART="ingress-nginx/ingress-nginx"
if ls charts/ingress-nginx-*.tgz >/dev/null 2>&1; then CHART=$(ls charts/ingress-nginx-*.tgz | head -1); fi
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm upgrade --install ingress-nginx "$CHART" \
  --namespace ingress-nginx --create-namespace \
  --version 4.12.0 \
  -f 01-ingress-nginx-values.yaml \
  --wait --timeout 180s
kubectl -n ingress-nginx get pods,svc
echo "Test : curl -s http://skyboard.local:8081/ -o /dev/null -w '%{http_code}\n'   (404 attendu tant qu'aucun Ingress nginx n'existe)"
