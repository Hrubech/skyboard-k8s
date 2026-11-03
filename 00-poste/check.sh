#!/usr/bin/env bash
# Vérifie le poste avant la formation. Sortie : OK / KO par outil. Code retour 1 si un KO.
set -u
ko=0
check() { if "$@" >/dev/null 2>&1; then printf '  OK  %s\n' "$1"; else printf '  KO  %s\n' "$1"; ko=1; fi; }
echo "== Outils"
check docker version
check docker run --rm hello-world
check kubectl version --client
check k3d version
check helm version
check jq --version
check hey -h
check k9s version
echo "== Ressources"
cpu=$(nproc); mem=$(free -g | awk '/Mem:/{print $2}'); disk=$(df -BG --output=avail / | tail -1 | tr -dc 0-9)
printf '  %s vCPU (min 4), %s Go RAM (min 8), %s Go libres (min 20)\n' "$cpu" "$mem" "$disk"
[ "$cpu" -ge 4 ] && [ "$mem" -ge 7 ] && [ "$disk" -ge 20 ] || { echo "  KO  ressources insuffisantes"; ko=1; }
echo "== Réseau"
check curl -fsSI https://registry-1.docker.io/v2/
check getent hosts k3d-registry.localhost
check getent hosts skyboard.local
echo "== Cluster (si créé)"
if kubectl get nodes >/dev/null 2>&1; then
  kubectl get nodes --no-headers | awk '{printf "  %s %s\n", ($2=="Ready"?"OK ":"KO "), $1}'
  kubectl get nodes --no-headers | grep -qv ' Ready' && ko=1
else
  echo "  --  pas de cluster (normal avant le TP1)"
fi
[ $ko -eq 0 ] && echo "Poste prêt." || echo "Poste NON prêt : voir les KO ci-dessus."
exit $ko
