# -*- mode: ruby -*-
# Vagrantfile — VM de TP « Kubernetes pour Développeurs » (SkyBoard), VirtualBox + Vagrant.
#
# Reproduit la VM demandée à IFORM : Ubuntu 24.04, 8 vCPU, 16 Go, 100 Go, sudo, HTTPS sortant,
# puis installe tout ce que les TP exigent (Docker, kubectl, k3d, helm, k9s, hey, jq, git, make, tree)
# et dépose le dépôt dans /home/vagrant/skyboard-k8s.
#
#   Prérequis poste : VirtualBox 7.x + Vagrant 2.4+ (et VT-x/AMD-V actif ; si le poste est lui-même une VM,
#                     la virtualisation imbriquée doit y être exposée).
#   Démarrage        : vagrant up                      (10 à 20 min la première fois : box + outils)
#   Connexion        : vagrant ssh                     (ou VS Code Remote-SSH : vagrant ssh-config >> ~/.ssh/config)
#   Vérification     : vagrant ssh -c 'cd skyboard-k8s && bash 00-poste/check.sh'
#   Précharger J-1   : vagrant provision --provision-with preload
#   Cluster (démo)   : vagrant provision --provision-with cluster   (les stagiaires le font au TP1)
#   Disque 100 Go    : VAGRANT_EXPERIMENTAL=disks vagrant up        (sinon : disque de la box, ~64 Go, largement suffisant)
#
#   Depuis le navigateur du poste : http://192.168.56.10 (Traefik), :8081 (ingress-nginx J3), :30080 (NodePort TP5)
#   Ajoutez dans C:\Windows\System32\drivers\etc\hosts :  192.168.56.10 skyboard.local dev.skyboard.local prod.skyboard.local helm.skyboard.local
#
#   Variables optionnelles : VM_NAME (nom VirtualBox), VM_CPUS, VM_MEM (Mo), VM_IP, HTTP_PROXY/HTTPS_PROXY/NO_PROXY (proxy d'entreprise)

VM_NAME  = ENV.fetch("VM_NAME",  "skyboard-k8s")
VM_CPUS  = ENV.fetch("VM_CPUS",  "8").to_i
VM_MEM   = ENV.fetch("VM_MEM",   "16384").to_i
VM_IP    = ENV.fetch("VM_IP",    "192.168.56.10")
REPO_URL = ENV.fetch("REPO_URL", "https://github.com/Hrubech/skyboard-k8s.git")

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"          # repli possible : "ubuntu/jammy64" (22.04, install.sh le supporte)
  config.vm.hostname = VM_NAME
  config.vm.boot_timeout = 600

  # Réseau : IP fixe host-only (navigateur et SSH depuis le poste) + redirections NAT de secours
  config.vm.network "private_network", ip: VM_IP
  config.vm.network "forwarded_port", guest: 80,    host: 8080,  auto_correct: true   # Traefik (Ingress J2)
  config.vm.network "forwarded_port", guest: 443,   host: 8443,  auto_correct: true
  config.vm.network "forwarded_port", guest: 8081,  host: 8081,  auto_correct: true   # ingress-nginx (atelier J3)
  config.vm.network "forwarded_port", guest: 30080, host: 30080, auto_correct: true   # NodePort (TP5)

  # Disque 100 Go (VAGRANT_EXPERIMENTAL=disks) ; sans le flag, Vagrant ignore cette ligne.
  config.vm.disk :disk, size: "100GB", primary: true

  # Le dépôt est aussi visible dans /vagrant (copie de secours si GitHub est inaccessible)
  config.vm.synced_folder ".", "/vagrant"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = VM_NAME
    vb.cpus   = VM_CPUS
    vb.memory = VM_MEM
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
    vb.customize ["modifyvm", :id, "--nestedpaging", "on"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
    vb.customize ["modifyvm", :id, "--vram", "16"]
  end

  # Proxy d'entreprise : les variables du poste sont propagées dans la VM (apt, curl, Docker, k3d)
  proxy_env = %w[HTTP_PROXY HTTPS_PROXY NO_PROXY].map { |k| [k, ENV[k] || ENV[k.downcase]] }.to_h.compact
  proxy_lines = proxy_env.map { |k, v| "#{k}=#{v}\n#{k.downcase}=#{v}" }.join("\n")

  # 1. Système : disque, proxy, hosts, locale, SSH
  config.vm.provision "system", type: "shell", privileged: true, inline: <<-SHELL
    set -eu
    export DEBIAN_FRONTEND=noninteractive
    # proxy (si fourni par le poste)
    if [ -n "#{proxy_lines}" ]; then
      printf '%s\n' "#{proxy_lines}" >> /etc/environment
      mkdir -p /etc/systemd/system/docker.service.d
      printf '[Service]\nEnvironment="#{proxy_env.map { |k, v| "#{k}=#{v}" }.join('" "')}"\n' > /etc/systemd/system/docker.service.d/http-proxy.conf
      printf 'Acquire::http::Proxy "%s";\nAcquire::https::Proxy "%s";\n' "#{proxy_env['HTTP_PROXY']}" "#{proxy_env['HTTPS_PROXY'] || proxy_env['HTTP_PROXY']}" > /etc/apt/apt.conf.d/95proxy
    fi
    # disque : étend la partition/LV racine si le disque a été agrandi (best effort)
    if command -v growpart >/dev/null 2>&1; then
      rootdev=$(findmnt -no SOURCE /) ; disk=$(lsblk -no PKNAME "$rootdev" 2>/dev/null || true)
      if [ -n "$disk" ]; then part=$(lsblk -no NAME "$rootdev" | head -1 | sed 's/[^0-9]*\\([0-9]*\\)$/\\1/'); growpart "/dev/$disk" "$part" 2>/dev/null || true; resize2fs "$rootdev" 2>/dev/null || true; fi
      if lvs >/dev/null 2>&1 && [ -n "$(lvs --noheadings 2>/dev/null)" ]; then pvresize $(pvs --noheadings -o pv_name | head -1) 2>/dev/null || true; lvextend -l +100%FREE -r "$(findmnt -no SOURCE /)" 2>/dev/null || true; fi
    fi
    # noms utilisés par les TP
    grep -q k3d-registry.localhost /etc/hosts || echo "127.0.0.1 k3d-registry.localhost" >> /etc/hosts
    for h in skyboard.local dev.skyboard.local prod.skyboard.local helm.skyboard.local; do grep -q " $h" /etc/hosts || echo "127.0.0.1 $h" >> /etc/hosts; done
    # confort : fr_FR, horloge, SSH par mot de passe pour VS Code/PuTTY si besoin (vagrant/vagrant)
    apt-get update -y >/dev/null
    apt-get install -y -q locales openssh-server >/dev/null
    locale-gen fr_FR.UTF-8 >/dev/null 2>&1 || true
    timedatectl set-timezone Europe/Paris || true
    sed -i 's/^#\\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config && systemctl restart ssh || true
    df -h / | tail -1
  SHELL

  # 2. Dépôt + outils (install.sh du dépôt, idempotent), en tant qu'utilisateur vagrant
  config.vm.provision "tools", type: "shell", privileged: false, inline: <<-SHELL
    set -eu
    cd "$HOME"
    if [ ! -d skyboard-k8s ]; then
      git clone #{REPO_URL} skyboard-k8s 2>/dev/null || { echo "GitHub inaccessible : copie depuis /vagrant"; cp -r /vagrant skyboard-k8s; rm -rf skyboard-k8s/.vagrant; }
    fi
    cd skyboard-k8s
    bash 00-poste/check-network.sh || echo "ATTENTION : des sorties réseau sont bloquées (voir ci-dessus) ; install.sh peut échouer."
    bash 00-poste/install.sh
    echo "cd ~/skyboard-k8s" >> "$HOME/.bashrc"
  SHELL

  # 3. Vérification finale (nouvelle session → groupe docker pris en compte)
  config.vm.provision "check", type: "shell", privileged: false, inline: <<-SHELL
    cd "$HOME/skyboard-k8s" && sg docker -c "bash 00-poste/check.sh" || true
  SHELL

  # Optionnels (vagrant provision --provision-with preload | cluster)
  config.vm.provision "preload", type: "shell", privileged: false, run: "never", inline: <<-SHELL
    cd "$HOME/skyboard-k8s" && sg docker -c "make cluster && make images && make preload"
  SHELL
  config.vm.provision "cluster", type: "shell", privileged: false, run: "never", inline: <<-SHELL
    cd "$HOME/skyboard-k8s" && sg docker -c "make cluster && make images"
  SHELL

  config.vm.post_up_message = <<~MSG
    VM SkyBoard prête : vagrant ssh   (dépôt dans ~/skyboard-k8s, alias k=kubectl)
    Navigateur du poste : http://#{VM_IP}  (ajoutez « #{VM_IP} skyboard.local » dans le fichier hosts de Windows)
    Précharger les images (J-1) : vagrant provision --provision-with preload
  MSG
end
