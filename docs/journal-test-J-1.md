# Déroulé de test complet (nuit J-1) et journal des frictions

Objectif : dérouler les 8 TP et l'atelier sur WSL2 dans l'ordre des stagiaires, noter chaque friction, et
sortir de la nuit avec (1) un dépôt corrigé et poussé, (2) la liste de ce qui change dans le cahier, (3) la
séquence « migration WSL » de 20 min pour demain matin.

Règle de travail : **on joue chaque TP avec les commandes du cahier, pas avec `make checkpoint`** (le checkpoint
sert ensuite à vérifier qu'il reproduit bien l'état). Chronomètre par TP. Toute commande qui ne donne pas la
sortie attendue est notée **immédiatement** dans le journal en bas, avec la sortie brute.

Priorité si la nuit est courte : bloc A (socle J2) > bloc B (J3) > bonus.

## Bloc 0 — Poste (déjà fait ce soir, à confirmer)

```bash
bash 00-poste/check.sh           # tout OK, pas de cluster = normal
```

## Bloc A — Reconstituer J1 puis dérouler J2 (environ 2 h)

### TP1 (15 min, version rapide)
```bash
make cluster                     # 3 nœuds Ready
make images                      # push v1/v2/web : l'erreur "HTTP response to HTTPS client" ne doit plus apparaître
curl -s k3d-registry.localhost:5000/v2/skyboard-api/tags/list      # {"name":"skyboard-api","tags":["v1","v2"]}
k get pods -n kube-system -o wide                                   # coredns, traefik, metrics-server, svclb-traefik×3
make preload                     # J-1 : aucune image à tirer demain
```

### TP2a + TP2b (20 min)
```bash
k apply -f 02-pods/01-pod-api.yaml && k port-forward pod/skyboard-api 8000:8000 &  curl -s localhost:8000/flights | head -c 200 ; kill %1
for f in 02-pods/broken/*.yaml; do k apply -f $f; done ; k get pods     # ImagePullBackOff / CrashLoopBackOff / Running mais port faux
k describe pod <pod-image-pull> | tail -8 ; k logs <pod-crashloop> --previous
k delete -f 02-pods/broken/ ; k delete pod skyboard-api
k apply -f 02-pods/03-pod-curl.yaml -f 02-pods/04-service-api.yaml -f 02-pods/05-deployment-api.yaml -f 02-pods/06-deployment-web.yaml
k scale deploy skyboard-api --replicas=5 ; k delete pod -l app.kubernetes.io/name=skyboard-api --wait=false ; k get pods -w   # self-healing
k exec toolbox -- sh -c 'for i in 1 2 3 4 5 6; do curl -s skyboard-api:8000/version; echo; done'   # alternance des réplicas
make checkpoint-2b               # doit être un no-op (tout "unchanged")
```

### TP3a — sondes (20 min)
```bash
k apply -f 03-lifecycle/01-deployment-probes.yaml ; k rollout status deploy/skyboard-api
k get endpointslices -l kubernetes.io/service-name=skyboard-api -o wide          # 3 adresses
POD=$(k get pod -l app.kubernetes.io/name=skyboard-api -o jsonpath='{.items[0].metadata.name}')
k exec $POD -- curl -s -X POST 'localhost:8000/admin/ready?state=false' ; sleep 15 ; k get endpointslices -l kubernetes.io/service-name=skyboard-api -o wide   # 2 adresses, RESTARTS inchangé
k exec $POD -- curl -s -X POST 'localhost:8000/admin/ready?state=true'
k exec $POD -- curl -s -X POST localhost:8000/admin/deadlock ; k get pods -w     # liveness → RESTARTS +1
```

### TP3b — init, arrêt propre, anti-affinité, priorités (25 min)
```bash
k apply -f 03-lifecycle/02-redis.yaml -f 03-lifecycle/03-deployment-init-prestop.yaml ; k get pods -w   # Init:0/1 puis Running
k apply -f 03-lifecycle/04-deployment-antiaffinity.yaml ; k get pods -o wide   # réplicas répartis sur agent-0 / agent-1
# rollout sous charge, avec arrêt propre : 0 erreur attendue
hey -z 30s -q 20 -c 5 http://localhost:8080/api/version & sleep 2 ; k set image deploy/skyboard-api api=k3d-registry.localhost:5000/skyboard-api:v2 ; wait
k apply -f 03-lifecycle/05-priorityclasses.yaml -f 03-lifecycle/06-deployment-noise.yaml ; k get pods -o wide   # bonus préemption
k delete -f 03-lifecycle/06-deployment-noise.yaml
```
Note : si `hey` sur `localhost:8080` ne répond pas, c'est que l'Ingress n'existe pas encore (TP5) : utiliser `k port-forward svc/skyboard-api 8000:8000` et `hey ... http://localhost:8000/version`. **À vérifier : ce que dit le cahier TP3b pour la charge → corriger si besoin.**

### TP4 — controllers (25 min)
```bash
k apply -f 04-controllers/01-deployment-rolling.yaml ; k rollout status deploy/skyboard-api ; k rollout history deploy/skyboard-api
k set image deploy/skyboard-api api=k3d-registry.localhost:5000/skyboard-api:v9 ; k rollout status deploy/skyboard-api --timeout=30s ; k rollout undo deploy/skyboard-api
k apply -f 04-controllers/02-hpa.yaml ; k top pods ; hey -z 2m -c 20 http://localhost:8080/api/flights & k get hpa -w     # ≥ 4 réplicas puis redescente (5 min)
k apply -f 04-controllers/03-redis-statefulset.yaml -f 04-controllers/04-daemonset-node-agent.yaml ; k get pods -o wide   # redis-0, node-agent ×3
k apply -f 04-controllers/05-job-notam-import.yaml ; k logs job/notam-import ; k apply -f 04-controllers/06-cronjob-notam-import.yaml ; k get cronjob,job
```

### TP5 — services (25 min)
```bash
k apply -f 05-services/01-service-clusterip.yaml -f 05-services/02-service-nodeport.yaml -f 05-services/03-service-loadbalancer.yaml -f 05-services/04-service-externalname.yaml -f 05-services/05-service-headless.yaml
k get svc ; curl -s localhost:30080/version                                           # NodePort via le port mappé
k exec toolbox -- nslookup skyboard-api ; k exec toolbox -- nslookup redis-0.redis   # DNS, headless
k apply -f 05-services/06-ingress-traefik.yaml ; curl -s -H 'Host: skyboard.local' localhost/api/flights | head -c 120 ; curl -s -H 'Host: skyboard.local' localhost/ | head -5
# depuis le navigateur Windows : http://skyboard.local (hosts Windows) ; sous WSL le port 80 est localhost:80 → vérifier que k3d a bien pu mapper 80/443 (sinon : voir journal)
bash 05-services/07-gateway-api-bonus.sh && k apply -f 05-services/08-gateway-httproute.yaml && k get httproute   # bonus
make checkpoint-5                # no-op attendu
```

## Bloc B — J3 (environ 1 h 15)

### TP6 — config et stockage (25 min)
```bash
k apply -f 06-storage/01-configmap-api.yaml -f 06-storage/02-secret-postgres.yaml -f 06-storage/03-postgres-statefulset.yaml -f 06-storage/05-deployment-api-config.yaml
k get pvc,pv ; k rollout status sts/postgres ; k rollout status deploy/skyboard-api
k apply -f 06-storage/06-cronjob-notam-import-db.yaml ; k create job --from=cronjob/notam-import notam-now ; k logs job/notam-now
curl -s -H 'Host: skyboard.local' localhost/api/flights | head -c 200 ; k delete pod postgres-0 ; k rollout status sts/postgres ; curl -s -H 'Host: skyboard.local' localhost/api/flights | head -c 200   # mêmes vols
k apply -f 06-storage/07-configmap-web-banner.yaml ; k patch deploy skyboard-web --patch-file 06-storage/08-patch-web-volume.yaml   # bonus rechargement
```

### TP7 — Kustomize et Helm (25 min)
```bash
k kustomize 07-kustomize/overlays/prod | head -40 ; diff <(k kustomize 07-kustomize/overlays/dev) <(k kustomize 07-kustomize/overlays/prod) | head
k apply -k 07-kustomize/overlays/dev ; k apply -k 07-kustomize/overlays/prod ; k get deploy,ingress -n dev ; k get deploy,ingress -n prod
curl -s -H 'Host: prod.skyboard.local' localhost/api/version
helm lint 07-helm/skyboard ; helm template skyboard 07-helm/skyboard | head -30     # PREMIÈRE exécution réelle du chart : noter toute erreur
helm install skyboard 07-helm/skyboard -n helm --create-namespace --wait ; helm upgrade skyboard 07-helm/skyboard -n helm --set image.api.tag=v2 --wait ; helm history skyboard -n helm ; helm rollback skyboard 1 -n helm
```

### Atelier (25 min) — suivre `solutions/08-atelier/SOLUTION.md` (branche solutions) ou les commentaires des fichiers
```bash
08-atelier/01-install-ingress-nginx.sh ; k get pods -n ingress-nginx
08-atelier/watch-split.sh http://skyboard.local:8081/api/version 50 &      # (nécessite skyboard.local dans /etc/hosts WSL : install.sh l'a fait)
k delete deploy skyboard-api --ignore-not-found ; k delete hpa skyboard-api --ignore-not-found
k apply -f 08-atelier/02-blue-deployment.yaml -f 08-atelier/04-service-blue-green.yaml -f 08-atelier/05-ingress-nginx-stable.yaml
k apply -f 08-atelier/03-green-deployment.yaml ; k rollout status deploy/skyboard-api-green
k patch svc skyboard-api -p '{"spec":{"selector":{"skyboard/slot":"green"}}}' ; sleep 10 ; k patch svc skyboard-api -p '{"spec":{"selector":{"skyboard/slot":"blue"}}}'
k apply -f 08-atelier/06-service-canary.yaml -f 08-atelier/07-ingress-nginx-canary.yaml ; sleep 20
k annotate ingress skyboard-nginx-canary nginx.ingress.kubernetes.io/canary-weight=50 --overwrite ; sleep 20 ; kill %1
```

## Bloc C — Vérifier les checkpoints depuis zéro (10 min, facultatif mais rassurant)
```bash
make clean-apps ; make checkpoint-5 ; make status      # doit reconstruire l'état fin J2 sans erreur
```

## Journal des frictions (à remplir au fil de l'eau)

| Heure | TP / étape | Commande | Sortie ou symptôme (brut) | Cause | Correctif (dépôt / cahier / script) | Fait ? |
| --- | --- | --- | --- | --- | --- | --- |
| 15h50 | TP1 étape 5 | `docker push k3d-registry.localhost:5000/skyboard-api:v1` | `server gave HTTP response to HTTPS client` | registry HTTP non déclarée dans Docker | `install.sh` écrit `insecure-registries` (poussé) | oui |
| 23h00 | poste | `install.sh` sur Ubuntu 26.04 | dépôt Docker sans `resolute` (à confirmer) | version Ubuntu plus récente que le dépôt | repli `noble` dans `install.sh` (poussé) | à confirmer |
|  |  |  |  |  |  |  |

## Sortie de la nuit (à compléter avant de dormir)

- Dépôt : commits poussés → `git log --oneline -5`
- Cahier J2 (TP3a, TP3b, TP4, TP5) : lignes à corriger → …
- Durées réelles par TP (socle) : TP3a … / TP3b … / TP4 … / TP5 …
- Séquence « migration WSL » du matin, validée : voir `docs/migration-wsl-J2.md`
