#!/usr/bin/env bash
# À lancer J-1 sur chaque poste, cluster créé : pré-charge toutes les images des TP
# pour qu'aucun pull n'ait lieu pendant la formation (réseau filtré).
set -euo pipefail
CLUSTER="${CLUSTER:-skyboard}"
REG="${REGISTRY:-k3d-registry.localhost:5000}"
IMAGES=(
  python:3.12-slim
  nginx:1.27-alpine
  redis:7-alpine
  postgres:16-alpine
  busybox:1.36
  curlimages/curl:8.11.1
  registry.k8s.io/metrics-server/metrics-server:v0.7.2
  registry.k8s.io/ingress-nginx/controller:v1.12.0
  registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.4
  registry.k8s.io/pause:3.10
)
for img in "${IMAGES[@]}"; do docker pull "$img"; done
k3d image import "${IMAGES[@]}" -c "$CLUSTER"
# Images applicatives : build + push registry locale
"$(dirname "$0")/../app/api/build.sh"
"$(dirname "$0")/../app/web/build.sh"
# Charts Helm en cache local
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update >/dev/null
helm pull ingress-nginx/ingress-nginx --version 4.12.0 -d "$(dirname "$0")/../08-atelier/charts" --untar=false
echo "Pré-chargement terminé."
