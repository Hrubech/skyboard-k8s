#!/usr/bin/env bash
set -euo pipefail
REG="${REGISTRY:-k3d-registry.localhost:5000}"          # nom vu par les nœuds (manifests)
PUSH="${REGISTRY_PUSH:-localhost:5000}"                 # nom utilisé pour pousser : localhost est toujours accepté en HTTP par Docker
cd "$(dirname "$0")"
docker build -t skyboard-web:v1 -t "$REG/skyboard-web:v1" -t "$PUSH/skyboard-web:v1" .
docker push "$PUSH/skyboard-web:v1"
