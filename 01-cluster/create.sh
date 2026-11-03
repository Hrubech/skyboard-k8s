#!/usr/bin/env bash
# TP1 — crée (ou recrée) le cluster k3d de formation.
set -euo pipefail
cd "$(dirname "$0")"
if k3d cluster list 2>/dev/null | grep -q '^skyboard '; then
  echo "Le cluster existe déjà. Suppression (k3d cluster delete skyboard) ? [o/N]"; read -r r
  [[ "$r" =~ ^[oO]$ ]] && k3d cluster delete skyboard || exit 0
fi
k3d cluster create --config k3d-config.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl get nodes -o wide
echo
echo "Cluster prêt. Contexte courant : $(kubectl config current-context)"
echo "Registry : k3d-registry.localhost:5000  (docker push k3d-registry.localhost:5000/<image>)"
