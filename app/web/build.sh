#!/usr/bin/env bash
set -euo pipefail
REG="${REGISTRY:-k3d-registry.localhost:5000}"
cd "$(dirname "$0")"
docker build -t skyboard-web:v1 -t "$REG/skyboard-web:v1" .
docker push "$REG/skyboard-web:v1"
