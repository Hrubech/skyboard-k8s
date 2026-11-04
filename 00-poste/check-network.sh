#!/usr/bin/env bash
# Vérifie, depuis la VM Ubuntu d'un stagiaire, que tout ce dont les TP ont besoin est joignable.
# À lancer AVANT install.sh, dès l'obtention des identifiants, puis à J-1 sur les 7 VM.
# Usage : bash 00-poste/check-network.sh          (aucun droit particulier requis)
set -u

ok()   { printf '  \033[32mOK\033[0m   %s\n' "$*"; }
ko()   { printf '  \033[31mKO\033[0m   %s\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$*"; }
FAIL=0

echo "== Système =="
. /etc/os-release 2>/dev/null && echo "  $PRETTY_NAME"
echo "  CPU : $(nproc) vCPU · RAM : $(free -g | awk '/Mem/{print $2}') Go · Disque / : $(df -h / | awk 'NR==2{print $4}') libres"
[ "$(nproc)" -ge 4 ] && ok "≥ 4 vCPU" || ko "moins de 4 vCPU"
[ "$(free -g | awk '/Mem/{print $2}')" -ge 7 ] && ok "≥ 8 Go RAM" || ko "moins de 8 Go RAM"
[ "$(df -BG / | awk 'NR==2{gsub("G","",$4); print $4}')" -ge 20 ] && ok "≥ 20 Go libres" || ko "moins de 20 Go libres"
sudo -n true 2>/dev/null && ok "sudo sans mot de passe" || warn "sudo demandera le mot de passe (normal) — vérifier qu'on l'a"

echo "== Proxy =="
if env | grep -qi '^https\?_proxy='; then
  warn "proxy défini : $(env | grep -i '^https\?_proxy=' | tr '\n' ' ')"
  echo "       → Docker (daemon) et les nœuds k3d devront le connaître : voir docs/environnement-reel.md"
else
  ok "aucun proxy dans l'environnement du shell"
fi

echo "== Sorties HTTPS indispensables =="
check_url() {  # url  libellé  [code attendu]
  code=$(curl -sS -o /dev/null -m 10 -w '%{http_code}' "$1" 2>/dev/null || echo 000)
  case "$code" in
    2*|3*|401|403|404) ok "$2 ($code)";;                 # joignable, même si le chemin répond 401/404
    *) ko "$2 — code $code (bloqué par le proxy / pare-feu ?)";;
  esac
}
check_url https://archive.ubuntu.com/ubuntu/                     "apt : archive.ubuntu.com"
check_url https://download.docker.com/linux/ubuntu/              "apt Docker : download.docker.com"
check_url https://registry-1.docker.io/v2/                       "Docker Hub : registry-1.docker.io"
check_url https://auth.docker.io/token                           "Docker Hub auth : auth.docker.io"
check_url https://registry.k8s.io/v2/                            "images Kubernetes : registry.k8s.io"
check_url https://ghcr.io/v2/                                    "GitHub Container Registry : ghcr.io"
check_url https://quay.io/v2/                                    "Quay : quay.io"
check_url https://github.com/k3d-io/k3d/releases                 "binaires k3d : github.com"
check_url https://objects.githubusercontent.com/                 "téléchargements GitHub : objects.githubusercontent.com"
check_url https://dl.k8s.io/release/stable.txt                   "binaire kubectl : dl.k8s.io"
check_url https://get.helm.sh/                                   "binaire helm : get.helm.sh"
check_url https://kubernetes.github.io/ingress-nginx/index.yaml  "chart ingress-nginx : kubernetes.github.io"
check_url https://pypi.org/simple/fastapi/                       "PyPI (build de l'image API) : pypi.org"
check_url https://files.pythonhosted.org/                        "PyPI fichiers : files.pythonhosted.org"
check_url https://kubernetes.io/fr/docs/                         "documentation : kubernetes.io"

echo "== Docker (si déjà installé) =="
if command -v docker >/dev/null 2>&1; then
  docker version --format '  client {{.Client.Version}} · serveur {{.Server.Version}}' 2>/dev/null \
    && ok "docker répond" || ko "docker installé mais le daemon ne répond pas (droits ? service ?)"
  docker info --format '{{.HTTPProxy}}' 2>/dev/null | grep -q . && warn "proxy configuré dans le daemon Docker : $(docker info --format '{{.HTTPProxy}}')"
  timeout 60 docker pull -q busybox:1.36 >/dev/null 2>&1 && ok "pull busybox depuis Docker Hub" || ko "pull busybox impossible (proxy du daemon ? rate limit Docker Hub ?)"
else
  warn "docker absent : normal avant install.sh"
fi

echo "== Accès depuis le poste Windows (à vérifier à la main) =="
echo "  IP de la VM : $(hostname -I 2>/dev/null | awk '{print $1}')"
echo "  → si vous voulez travailler en SSH / VS Code Remote depuis le poste RDP, cette IP doit être joignable"
echo "    (réseau bridged ou host-only de l'hyperviseur, ou redirection du port 22 en NAT)."
command -v sshd >/dev/null 2>&1 && ok "serveur SSH présent" || warn "pas de serveur SSH : sudo apt install openssh-server"

echo
[ "$FAIL" -eq 0 ] && echo "Résultat : tout est joignable, install.sh peut tourner." \
                  || echo "Résultat : $FAIL point(s) bloquant(s) — à remonter à IFORM / l'hébergeur avant J-1."
exit "$FAIL"
