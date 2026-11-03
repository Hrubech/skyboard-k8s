# De Docker Compose à Kubernetes — table de correspondance

Le fichier `app/docker-compose.yml` fait tourner SkyBoard sur un poste de développeur.
Chaque ligne ci-dessous dit par quoi la notion Compose est remplacée dans Kubernetes et dans quel TP du dépôt on la rencontre.

| Docker Compose | Kubernetes | Dans le dépôt | Ce qui change vraiment |
| --- | --- | --- | --- |
| `services.api` (un container) | `Pod` → `Deployment` (replicas, template) | `02-pods/01-pod-api.yaml`, `02-pods/05-deployment-api.yaml` | Le container n'est plus l'unité : c'est le Pod, et on ne le crée jamais à la main en prod |
| `build: ./api` | Rien : l'image est construite **avant**, hors du cluster, et poussée dans une registry | `Makefile` cible `images`, registry k3d | Kubernetes ne construit pas ; CI/CD ou poste de dev s'en chargent |
| `image: skyboard-api:v1` | `spec.containers[].image` + `imagePullPolicy` + `imagePullSecrets` si registry privée | tous les manifests | Toujours un tag explicite ou un digest, jamais `latest` |
| `environment:` | `env`, `envFrom` → `ConfigMap` et `Secret` | `06-storage/` | Config et secrets sortent du manifest de l'application ; même image en dev et prod |
| `depends_on` | `initContainers` (attente), sondes `readiness` (ne pas recevoir de trafic tant que la dépendance manque) | `03-lifecycle/03-deployment-init-prestop.yaml` | Pas d'ordre de démarrage garanti : l'application doit tolérer l'absence temporaire d'une dépendance |
| `healthcheck:` | `livenessProbe`, `readinessProbe`, `startupProbe` | `03-lifecycle/01-deployment-probes.yaml` | Trois sondes aux rôles distincts ; readiness pilote le trafic, liveness le redémarrage |
| `stop_grace_period` | `terminationGracePeriodSeconds` + hook `preStop` + gestion de SIGTERM dans le code | `03-lifecycle/03-deployment-init-prestop.yaml`, `app/api/main.py` | Le code doit drainer puis s'arrêter : c'est la condition du « zéro erreur » en rolling update |
| `deploy.resources.limits` | `resources.requests` et `resources.limits` | tous les manifests | `requests` sert au placement et à l'HPA ; `limits` plafonne |
| `ports: "8080:8080"` | `Service` (ClusterIP, NodePort, LoadBalancer) puis `Ingress` / `HTTPRoute` | `05-services/` | Les Pods changent d'IP ; le Service est l'adresse stable, l'Ingress la porte d'entrée HTTP |
| Nom de service DNS (`redis`, `postgres`) | Nom du `Service` : `redis`, `redis.default.svc.cluster.local` | `05-services/01-service-clusterip.yaml` | Même réflexe, mais résolu par CoreDNS et borné au namespace |
| `volumes: pgdata:` | `PersistentVolumeClaim` + `StorageClass` (+ `volumeClaimTemplates` dans un StatefulSet) | `06-storage/` | Le stockage est demandé (claim) et provisionné dynamiquement ; il survit au Pod |
| `restart: "no"` + tâche ponctuelle | `Job` ; planifié → `CronJob` | `04-controllers/05-job-notam-import.yaml`, `06-cronjob` | Reprise sur erreur (`backoffLimit`), parallélisme, historique |
| `docker compose up` | `kubectl apply -k overlays/dev` ou `helm install` | `07-kustomize/`, `07-helm/` | Un seul `apply` idempotent ; les différences dev/prod sont des overlays ou des values, pas des fichiers dupliqués |
| `docker compose logs -f api` | `kubectl logs -f deploy/skyboard-api --all-containers` | partout | Les logs vont sur stdout/stderr ; un agent (DaemonSet) les centralise |
| `docker compose up --scale api=3` | `kubectl scale deploy/skyboard-api --replicas=3` ou `HorizontalPodAutoscaler` | `04-controllers/02-hpa.yaml` | Le scale peut devenir automatique sur une métrique |
| Réseau par défaut d'un projet Compose | `Namespace` + (hors programme) `NetworkPolicy` | plan B : 1 namespace par stagiaire | Isolation logique par namespace, filtrage réseau par policy |

## Ce que Compose ne vous a jamais demandé et que Kubernetes exige

1. Une image **immuable et taguée**, construite ailleurs.
2. Une application qui **démarre dans n'importe quel ordre** et attend ses dépendances.
3. Des **sondes** honnêtes : `/healthz` ne teste que le process, `/readyz` teste ce dont on a besoin pour servir.
4. Un **arrêt propre** sur SIGTERM, dans le délai de grâce.
5. Des **ressources déclarées** : sans `requests`, pas de placement fiable ni d'HPA.
6. La **config hors de l'image** : variables d'environnement, fichiers montés, jamais de valeur codée en dur.
7. Un processus **non-root**, système de fichiers en lecture seule si possible (`securityContext`).

Bonus : `kompose convert` (kompose.io) traduit mécaniquement un `docker-compose.yml` en manifests ; utile pour un premier jet, jamais pour la prod — comparez sa sortie avec `02-pods/05-deployment-api.yaml` pour voir tout ce qu'il ne sait pas écrire (sondes, ressources, securityContext, anti-affinité).
