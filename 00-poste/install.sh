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
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
fi
sudo usermod -aG docker "$USER" || true

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
curl -fsSLo /tmp/hey "https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_${ARCH}" && sudo install -m 0755 /tmp/hey /usr/local/bin/hey

# Résolution du nom de la registry k3d depuis le poste
grep -q "k3d-registry.localhost" /etc/hosts || echo "127.0.0.1 k3d-registry.localhost" | sudo tee -a /etc/hosts
grep -q "skyboard.local" /etc/hosts || echo "127.0.0.1 skyboard.local" | sudo tee -a /etc/hosts

# Complétion et alias
grep -q 'alias k=kubectl' ~/.bashrc || cat >> ~/.bashrc <<'RC'
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
export KUBE_EDITOR=nano
RC
echo "Installation terminée. Déconnectez-vous / reconnectez-vous (groupe docker), puis lancez 00-poste/check.sh"
