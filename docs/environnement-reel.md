# Environnement réel de la session DGAC — chaîne d'accès et préparation

Constaté le 2026-11-02 : chaque stagiaire (et le formateur) se connecte en **RDP** à un poste ; sur ce poste, un **hyperviseur** héberge une **VM Ubuntu 24.04** (8 vCPU, 16 Go, 100 Go, sudo, HTTPS sortant). Le formateur peut prendre la main en **VNC** sur les postes des stagiaires.

```
Stagiaire ──RDP──▶ Poste (Windows) ──hyperviseur──▶ VM Ubuntu 24.04 ──Docker──▶ k3d (server + 2 agents + registry)
                        ▲
Formateur ──VNC─────────┘   (support : voir l'écran, prendre la main)
```

## Ce que cela valide

- Plan A (k3d local) confirmé, avec de la marge : 8 vCPU / 16 Go permettent les 3 nœuds, l'HPA sous charge, PostgreSQL et ingress-nginx sans ralentissement.
- Docker dans une VM Linux ne nécessite pas de virtualisation imbriquée (les containers sont des processus) : le fait que la VM démarre suffit.
- Le VNC remplace le partage d'écran Teams pour le support : plus rapide, et il permet d'agir.

## Ce qu'il faut vérifier dès l'obtention des identifiants

| Vérification | Commande / où regarder | Si KO |
| --- | --- | --- |
| Réseau sortant complet | `bash 00-poste/check-network.sh` dans la VM | Remonter la liste des domaines bloqués à IFORM ; prévoir `preload-images.sh` depuis une machine qui y accède |
| Proxy d'entreprise | `env \| grep -i proxy` ; `cat /etc/apt/apt.conf.d/*proxy*` | Configurer Docker (`/etc/systemd/system/docker.service.d/http-proxy.conf`) **et** passer `--env HTTP_PROXY=…@server:0;agent:*` à `k3d cluster create` pour que les nœuds tirent les images |
| Docker déjà installé ? | `docker version` | Sinon `install.sh` le fait ; prévoir 5-10 min par VM, réseau dépendant |
| Interface graphique dans la VM ? | `echo $XDG_SESSION_TYPE`, présence de Firefox | Sans GUI, le navigateur est sur le poste Windows : il faut joindre la VM depuis le poste (voir ci-dessous) |
| VM joignable depuis le poste Windows | `hostname -I` dans la VM, puis `ping` / `ssh` depuis le poste | Réseau NAT sans redirection : passer en bridged/host-only ou ajouter les redirections 22, 80, 443, 8081, 30080 |
| Serveur SSH | `systemctl status ssh` | `sudo apt install openssh-server` |
| Presse-papiers RDP → console hyperviseur | Coller une commande depuis le cahier PDF | Travailler en SSH depuis le poste (Windows Terminal, PuTTY, VS Code Remote-SSH) : le collage fonctionne toujours |
| Horloge et DNS de la VM | `timedatectl`, `resolvectl status` | Une horloge fausse casse TLS et les pulls ; corriger NTP |

## Mode de travail recommandé pour le stagiaire

Travailler **en SSH depuis le poste Windows** vers la VM (Windows Terminal ou VS Code + extension Remote-SSH), plutôt que dans la console de l'hyperviseur : copier-coller fiable, plusieurs terminaux, VS Code pour éditer les manifests, et le navigateur du poste atteint `http://<ip-vm>:8081` et `http://skyboard.local` après ajout de la ligne dans `C:\Windows\System32\drivers\etc\hosts` (droits admin sur le poste requis ; sinon utiliser `curl -H 'Host: skyboard.local' http://<ip-vm>` dans la VM).

## Installation des outils : à J-1 par le formateur, pas en direct

La demande initiale prévoyait l'installation « avec les stagiaires ». Installer Docker et quatre binaires en direct à 7 n'a aucune valeur pédagogique et porte tout le risque réseau de la journée 1. Recommandation :

1. **J-1, via VNC/RDP, sur les 7 VM** : `check-network.sh`, puis `install.sh`, puis `preload-images.sh`, puis `check.sh`. Compter 15 min par VM, en parallèle sur plusieurs sessions VNC.
2. **J1 9h15, en tâche de fond** (si J-1 n'a pas été possible) : chaque stagiaire lance `bash 00-poste/install.sh` dans un terminal pendant le tour de table ; le script tourne 10 min sans intervention ; `check.sh` à 11h00 au début du TP1.
3. **Le TP1 garde ce qui s'apprend** : création du cluster k3d, kubeconfig, exploration, import d'image. L'installation d'outils n'y figure pas.

Si IFORM tient à ce que les stagiaires installent eux-mêmes, lire `install.sh` ensemble (3 min) est suffisant : chaque ligne y est commentée.

## Support pendant la session

- Le canal Teams « Entraide » reste le premier réflexe (le stagiaire colle son erreur).
- En second, le VNC : **toujours demander** avant de prendre la main (« je regarde ton écran ? »), annoncer ce qu'on fait, rendre la main. Pour un groupe DGAC, cette étiquette compte autant que la solution.
- Le tour des terminaux peut se faire en VNC plutôt qu'en partage d'écran Teams : plus discret pour les stagiaires fragiles.
