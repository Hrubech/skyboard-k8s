#!/usr/bin/env bash
# Installation des outils du poste stagiaire (Ubuntu 22.04/24.04, droits sudo).
# À exécuter par IFORM sur l'image du poste virtuel à J-7. Idempotent.
set -euo pipefail
K3D_VERSION="${K3D_VERSION:-v5.7.5}"
KUBECTL_VERSION="${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}"
HELM_VERSION="${HELM_VERSION:-v3.16.3}"
K9S_VERSION="${K9S_VERSION:-v0.32.7}"
ARCH=$(dpkg --print-architecture)   # amd64 ou arm64

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg jq git make unzip apache2-utils tree

# Docker Engine (dépôt officiel)
if ! command -v docker >/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  # Ubuntu plus récent que le dépôt Docker (ex. 26.04 avant sa prise en charge) : repli sur la LTS précédente
  if ! curl -fsSI "https://download.docker.com/linux/ubuntu/dists/${CODENAME}/Release" >/dev/null 2>&1; then
    echo "Dépôt Docker indisponible pour '${CODENAME}', utilisation des paquets 'noble' (24.04)."; CODENAME=noble
  fi
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
fi
sudo usermod -aG docker "$USER" || true

# La registry k3d sert en HTTP : Docker doit la connaître comme « insecure », sinon « server gave HTTP response to HTTPS client »
if ! grep -q "k3d-registry.localhost:5000" /etc/docker/daemon.json 2>/dev/null; then
  if [ -s /etc/docker/daemon.json ]; then
    sudo jq '. + {"insecure-registries": ((."insecure-registries" // []) + ["k3d-registry.localhost:5000"] | unique)}' /etc/docker/daemon.json | sudo tee /etc/docker/daemon.json.new >/dev/null \
      && sudo mv /etc/docker/daemon.json.new /etc/docker/daemon.json
  else
    echo '{ "insecure-registries": ["k3d-registry.localhost:5000"] }' | sudo tee /etc/docker/daemon.json >/dev/null
  fi
  sudo systemctl restart docker
fi

# kubectl
curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl

# k3d
curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=$K3D_VERSION bash

# helm
curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz | tar xz -C /tmp
sudo install -m 0755 /tmp/linux-${ARCH}/helm /usr/local/bin/helm

# k9s (confort) et hey (charge pour le HPA)
curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz" | tar xz -C /tmp k9s
sudo install -m 0755 /tmp/k9s /usr/local/bin/k9s
# hey : paquet Ubuntu (universe) d'abord, téléchargement en repli
command -v hey >/dev/null || sudo apt-get install -y hey >/dev/null 2>&1 \
  || { curl -fsSLo /tmp/hey "https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_${ARCH}" && sudo install -m 0755 /tmp/hey /usr/local/bin/hey; } \
  || echo "hey non installé : utiliser 'ab' (apache2-utils) pour la charge du TP4"

# WSL régénère /etc/hosts à chaque démarrage : on l'en empêche, sinon les noms ci-dessous disparaissent
if grep -qi microsoft /proc/version 2>/dev/null; then
  if ! grep -q "generateHosts" /etc/wsl.conf 2>/dev/null; then
    printf '\n[network]\ngenerateHosts=false\n' | sudo tee -a /etc/wsl.conf >/dev/null
  fi
  if ! grep -q "vmIdleTimeout" "$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")/.wslconfig" 2>/dev/null; then
    echo "Conseil : ajoutez vmIdleTimeout=-1 sous [wsl2] dans votre .wslconfig Windows pour que WSL ne s'arrête pas quand le terminal est fermé."
  fi
fi

# Résolution du nom de la registry k3d depuis le poste
grep -q "k3d-registry.localhost" /etc/hosts || echo "127.0.0.1 k3d-registry.localhost" | sudo tee -a /etc/hosts
grep -q " skyboard.local" /etc/hosts || echo "127.0.0.1 skyboard.local dev.skyboard.local prod.skyboard.local helm.skyboard.local" | sudo tee -a /etc/hosts

# Complétion et alias
grep -q 'alias k=kubectl' ~/.bashrc || cat >> ~/.bashrc <<'RC'
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
export KUBE_EDITOR=nano
RC
echo "Installation terminée. Déconnectez-vous / reconnectez-vous (groupe docker), puis lancez 00-poste/check.sh"
