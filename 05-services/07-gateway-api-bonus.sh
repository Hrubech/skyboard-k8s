#!/usr/bin/env bash
# TP5 — bonus : activer la Gateway API sur le Traefik de k3s (à tester à J-1 ; sinon démo formateur)
set -euo pipefail
# 1. CRDs standard de la Gateway API
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
# 2. Activer le provider Gateway API dans le Traefik géré par k3s (HelmChartConfig)
kubectl apply -f - <<'YAML'
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    providers:
      kubernetesGateway:
        enabled: true
    gateway:
      enabled: false
YAML
kubectl -n kube-system rollout status deploy/traefik --timeout=120s
echo "Gateway API activée : appliquez 08-gateway-httproute.yaml"
