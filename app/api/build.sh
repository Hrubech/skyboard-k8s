#!/usr/bin/env bash
# Construit skyboard-api v1 et v2 et les pousse dans la registry k3d locale.
set -euo pipefail
REG="${REGISTRY:-k3d-registry.localhost:5000}"
cd "$(dirname "$0")"
for v in v1 v2; do
  docker build --build-arg APP_VERSION=$v -t skyboard-api:$v -t "$REG/skyboard-api:$v" .
  docker push "$REG/skyboard-api:$v"
done
echo "Images disponibles : $REG/skyboard-api:{v1,v2}"
