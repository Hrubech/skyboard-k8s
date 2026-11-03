# skyboard-k8s — dépôt de TP « Kubernetes pour Développeurs » (IF-KUBDEV, DGAC)

SkyBoard est un tableau des vols minimaliste (API FastAPI + front nginx + Redis + PostgreSQL + import planifié) qui sert
de fil rouge pendant les 3 jours : chaque TP ajoute une brique Kubernetes à la même application.

## Arborescence
```
app/            code source et Dockerfiles (api, web, notam-import) + docker-compose.yml (point de départ dev)
00-poste/       check-network.sh (sorties HTTPS, proxy), install.sh (outils), preload-images.sh (J-1), check.sh
01-cluster/     k3d-config.yaml + create.sh                         → TP1
02-pods/        Pod, pannes volontaires (broken/), Service, Deployment → TP2a / TP2b
03-lifecycle/   sondes, init container, preStop, affinités, priorités → TP3a / TP3b
04-controllers/ RollingUpdate, HPA, StatefulSet, DaemonSet, Job, CronJob → TP4
05-services/    ClusterIP, NodePort, LoadBalancer, ExternalName, headless, Ingress, Gateway API → TP5
06-storage/     ConfigMap, Secret, PVC/StorageClass, PostgreSQL, CronJob en base → TP6
07-kustomize/   base + overlays dev / prod                            → TP7
07-helm/        chart skyboard                                       → TP7
08-atelier/     ingress-nginx, blue/green, canary, HTTPRoute pondérée → atelier J3
checkpoints/    restore.sh <tp> : remet le cluster à l'état de fin d'un TP
docs/           compose-vers-kubernetes.md, logs-et-monitoring.md, environnement-reel.md (chaîne RDP/VM, préparation J-1)
cheatsheet.md   mémo kubectl 1 page
```

## VM de TP avec VirtualBox + Vagrant
`vagrant up` à la racine du dépôt crée une VM Ubuntu 24.04 vierge (8 vCPU, 16 Go), y installe tous les outils et dépose le dépôt dans `~/skyboard-k8s` (voir l'en-tête du `Vagrantfile`). IP fixe `192.168.56.10` pour le navigateur du poste.

## Prérequis poste (plan A)
Ubuntu 22.04+ (ou équivalent), 4 vCPU, 8 Go RAM, 20 Go libres, Docker, droits `docker` pour l'utilisateur.
`00-poste/install.sh` installe docker, kubectl, k3d, helm, k9s, hey, jq et ajoute `k3d-registry.localhost`
et `skyboard.local` dans `/etc/hosts`. Puis `make check`.

## Démarrage rapide
```bash
git clone https://github.com/Hrubech/skyboard-k8s.git && cd skyboard-k8s
make cluster      # crée le cluster skyboard (1 server + 2 agents + registry, ports 80/443/8081/30080)
make images       # construit skyboard-api:v1/v2 et skyboard-web:v1, pousse dans la registry k3d
make preload      # (J-1) pré-charge toutes les images des TP : aucun pull pendant la formation
kubectl apply -f 02-pods/01-pod-api.yaml
kubectl port-forward pod/skyboard-api 8000:8000 &  curl localhost:8000/flights
```

## Rattraper un TP
`make checkpoint-3b` applique l'état attendu en fin de TP3b (rejoue les TP précédents, idempotent).

## Conventions des manifests
Labels `app.kubernetes.io/name|part-of|version` partout · `resources` requests/limits toujours renseignés ·
`securityContext` non-root, sans privilèges · un fichier par étape, numéroté dans l'ordre du cahier de TP ·
les commentaires en tête de fichier indiquent le TP et l'étape.

## Plan B (cluster mutualisé)
Sur un k3s partagé : un namespace par stagiaire (`kubectl config set-context --current --namespace=<prenom>`),
remplacer `k3d-registry.localhost:5000/` par la registry fournie par le formateur. Les manifests cluster-wide
(PriorityClass, DaemonSet, Namespace legacy/dev/prod, ingress-nginx, Gateway) sont alors joués en démo.

## Plan C (bac à sable navigateur)
Les manifests de 02 à 06 fonctionnent tels quels sur un playground Killercoda (sans Ingress/LoadBalancer),
avec l'image publique de secours indiquée par le formateur.

## Branches
- `main` : le matériel des TP tel que distribué aux stagiaires (manifests par étape, exercices `# TODO` non résolus).
- `solutions` : `main` + le dossier `solutions/` (corrigés des exercices à compléter et solution commentée de l'atelier). Partagée en fin de session.
