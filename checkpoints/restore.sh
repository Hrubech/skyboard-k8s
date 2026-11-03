#!/usr/bin/env bash
# Remet le cluster dans l'état attendu EN FIN d'un TP donné (rattrapage d'un stagiaire en retard).
# Usage : checkpoints/restore.sh <tp>   avec tp ∈ 1 | 2a | 2b | 3a | 3b | 4 | 5 | 6 | 7 | atelier
# Chaque niveau rejoue les précédents : idempotent (kubectl apply).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TP="${1:?indiquez le TP : 1 2a 2b 3a 3b 4 5 6 7 atelier}"
k() { kubectl "$@"; }
need_cluster() { k get nodes >/dev/null 2>&1 || { echo "Pas de cluster : lancez 01-cluster/create.sh"; exit 1; }; }

step1()  { need_cluster; k get nodes; }
step2a() { k apply -f "$ROOT/02-pods/03-pod-curl.yaml"; k delete pod skyboard-api --ignore-not-found; }
step2b() { k apply -f "$ROOT/02-pods/04-service-api.yaml" -f "$ROOT/02-pods/05-deployment-api.yaml" -f "$ROOT/02-pods/06-deployment-web.yaml"; }
step3a() { k apply -f "$ROOT/03-lifecycle/01-deployment-probes.yaml"; }
step3b() { k apply -f "$ROOT/03-lifecycle/02-redis.yaml" -f "$ROOT/03-lifecycle/03-deployment-init-prestop.yaml" -f "$ROOT/03-lifecycle/05-priorityclasses.yaml"
           k patch deployment skyboard-api --patch-file "$ROOT/03-lifecycle/04-deployment-antiaffinity.yaml"; }
step4()  { k delete deployment redis --ignore-not-found; k apply -f "$ROOT/04-controllers/03-redis-statefulset.yaml" -f "$ROOT/04-controllers/01-deployment-rolling.yaml" -f "$ROOT/04-controllers/02-hpa.yaml" -f "$ROOT/04-controllers/04-daemonset-node-agent.yaml" -f "$ROOT/04-controllers/06-cronjob-notam-import.yaml"
           k patch deployment skyboard-api --patch-file "$ROOT/03-lifecycle/04-deployment-antiaffinity.yaml"; }
step5()  { k apply -f "$ROOT/05-services/01-service-clusterip.yaml" -f "$ROOT/05-services/02-service-nodeport.yaml" -f "$ROOT/05-services/03-service-loadbalancer.yaml" -f "$ROOT/05-services/04-service-externalname.yaml" -f "$ROOT/05-services/05-service-headless.yaml" -f "$ROOT/05-services/06-ingress-traefik.yaml"; }
step6()  { k apply -f "$ROOT/06-storage/01-configmap-api.yaml" -f "$ROOT/06-storage/02-secret-postgres.yaml" -f "$ROOT/06-storage/03-postgres-statefulset.yaml" -f "$ROOT/06-storage/05-deployment-api-config.yaml"
           k create configmap notam-import-script --from-file=import.sh="$ROOT/app/notam-import/import.sh" --dry-run=client -o yaml | k apply -f -
           k apply -f "$ROOT/06-storage/06-cronjob-notam-import-db.yaml"; }
step7()  { k apply -k "$ROOT/07-kustomize/overlays/dev"; k apply -k "$ROOT/07-kustomize/overlays/prod"
           helm upgrade --install skyboard "$ROOT/07-helm/skyboard" --namespace helm --create-namespace --wait --timeout 120s; }
stepat() { "$ROOT/08-atelier/01-install-ingress-nginx.sh"
           k delete hpa skyboard-api --ignore-not-found; k delete deployment skyboard-api --ignore-not-found
           k apply -f "$ROOT/08-atelier/02-blue-deployment.yaml" -f "$ROOT/08-atelier/03-green-deployment.yaml" -f "$ROOT/08-atelier/04-service-blue-green.yaml" -f "$ROOT/08-atelier/05-ingress-nginx-stable.yaml" -f "$ROOT/08-atelier/06-service-canary.yaml" -f "$ROOT/08-atelier/07-ingress-nginx-canary.yaml"; }

order=(1 2a 2b 3a 3b 4 5 6 7 atelier)
for s in "${order[@]}"; do
  case "$s" in atelier) fn=stepat;; *) fn="step$s";; esac
  echo "== checkpoint $s"; $fn
  [[ "$s" == "$TP" ]] && break
done
k rollout status deployment/skyboard-api --timeout=120s 2>/dev/null || true
echo "État fin de TP $TP restauré."
