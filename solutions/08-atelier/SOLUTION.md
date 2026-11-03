# Atelier J3 — solution commentée : livrer SkyBoard v2 sans coupure

Contrainte : zéro requête en erreur, retour arrière < 10 s, exposition progressive 10 % → 50 % → 100 %.
Toutes les commandes se lancent depuis la racine du dépôt ; `k` = `kubectl`.

## 0. Sonde de trafic (terminal dédié, à laisser tourner jusqu'à la fin)
```bash
08-atelier/watch-split.sh http://skyboard.local:8081/api/version 50
```

## 1. Ingress Controller nginx (port 8081, Traefik garde 80/443)
```bash
08-atelier/01-install-ingress-nginx.sh            # helm install ingress-nginx -f 08-atelier/01-ingress-nginx-values.yaml
k get pods -n ingress-nginx -w                     # attendre Running 1/1
```

## 2. « Production » = blue (v1)
```bash
k delete deploy skyboard-api --ignore-not-found ; k delete hpa skyboard-api --ignore-not-found   # sinon le Service verrait aussi ces Pods
k apply -f 08-atelier/02-blue-deployment.yaml -f 08-atelier/04-service-blue-green.yaml -f 08-atelier/05-ingress-nginx-stable.yaml
curl -s http://skyboard.local:8081/api/version     # → v1 ; la sonde affiche 100 % v1
```

## 3. Blue/green
```bash
k apply -f 08-atelier/03-green-deployment.yaml     # v2 démarre à côté, sans trafic
k rollout status deploy/skyboard-api-green         # attendre que les sondes readiness soient vertes
k patch svc skyboard-api -p '{"spec":{"selector":{"skyboard/slot":"green"}}}'   # bascule : 100 % v2, instantané
k patch svc skyboard-api -p '{"spec":{"selector":{"skyboard/slot":"blue"}}}'    # retour arrière : < 1 s
```
Observation attendue : 0 erreur sur la sonde dans les deux sens. Pourquoi ? Les Pods green sont déjà `Ready` avant
de recevoir du trafic (readiness), et les Pods blue ne sont pas arrêtés, seulement plus sélectionnés.

## 4. Canary
```bash
k apply -f 08-atelier/06-service-canary.yaml -f 08-atelier/07-ingress-nginx-canary.yaml     # 10 % vers green
k annotate ingress skyboard-nginx-canary nginx.ingress.kubernetes.io/canary-weight=50 --overwrite
k annotate ingress skyboard-nginx-canary nginx.ingress.kubernetes.io/canary-weight=100 --overwrite
```
Observation attendue : la sonde passe d'environ 10 % à 50 % puis 100 % de v2, sans erreur.
Retour arrière canary : `--overwrite canary-weight=0` (ou `k delete ingress skyboard-nginx-canary`).

Test ciblé par en-tête (équipe de recette) : remettre le poids à 0, puis
`k annotate ingress skyboard-nginx-canary nginx.ingress.kubernetes.io/canary-by-header=X-Canary --overwrite`
et `curl -s -H 'X-Canary: always' http://skyboard.local:8081/api/version` → v2 pour ce seul client.

## 5. Généralisation propre
Une fois le canary à 100 % validé : basculer le Service stable sur green (étape 3), supprimer l'Ingress canary et le
Service canary, puis scaler blue à 0 (`k scale deploy skyboard-api-blue --replicas=0`) — on le garde quelques heures
pour un retour arrière immédiat, on le supprime ensuite.

## Pourquoi zéro 502 quand un Pod s'arrête
readiness (retrait des EndpointSlices avant l'arrêt) + `preStop` + gestion de SIGTERM dans `main.py` (drain des
requêtes en cours) + `terminationGracePeriodSeconds` supérieur au temps de drain.

## Bonus — Gateway API
`08-atelier/08-bonus-httproute-weights.yaml` : le même canary en une seule `HTTPRoute` avec deux `backendRefs` pondérés,
sans annotation propriétaire. Comparer avec les deux Ingress nginx : c'est l'argument de la Gateway API.
