# Mémo kubectl — Kubernetes pour Développeurs (SkyBoard)

`alias k=kubectl` · complétion : `source <(kubectl completion bash)` · namespace courant : `k config set-context --current --namespace=dev`

## Voir
| Besoin | Commande |
| --- | --- |
| Tout ce qui tourne | `k get all` · `k get pods -o wide` · `k get pods -w` |
| Détail + événements d'un objet | `k describe pod <pod>` |
| Événements du namespace, triés | `k get events --sort-by=.lastTimestamp` · `k get events -w` |
| Logs | `k logs <pod>` · `-f` suit · `-c <container>` · `--previous` (container précédent) · `-l app.kubernetes.io/name=skyboard-api --prefix` |
| YAML réel d'un objet | `k get deploy skyboard-api -o yaml` · `-o jsonpath='{.spec.replicas}'` |
| Documentation d'un champ | `k explain pod.spec.containers.livenessProbe` · `k explain deployment --recursive \| less` |
| API disponibles | `k api-resources` · `k api-versions` |
| Consommation | `k top nodes` · `k top pods` |

## Agir
| Besoin | Commande |
| --- | --- |
| Appliquer / supprimer un manifest | `k apply -f fichier.yaml` · `k delete -f fichier.yaml` · `k apply -k overlays/dev` |
| Voir le diff avant d'appliquer | `k diff -f fichier.yaml` |
| Générer un squelette YAML | `k create deploy api --image=nginx --dry-run=client -o yaml > deploy.yaml` |
| Entrer dans un container | `k exec -it <pod> -- sh` · `k exec <pod> -c api -- env` |
| Pod jetable de test | `k run tmp --rm -it --image=curlimages/curl:8.11.1 -- sh` |
| Déboguer sans shell dans l'image | `k debug -it <pod> --image=busybox:1.36 --target=api` |
| Accéder depuis le poste | `k port-forward svc/skyboard-api 8000:8000` |
| Scaler | `k scale deploy skyboard-api --replicas=5` |
| Mettre à jour l'image | `k set image deploy/skyboard-api api=k3d-registry.localhost:5000/skyboard-api:v2` |
| Suivre / annuler un rollout | `k rollout status deploy/skyboard-api` · `k rollout history deploy/skyboard-api` · `k rollout undo deploy/skyboard-api --to-revision=1` |
| Redémarrer proprement | `k rollout restart deploy/skyboard-api` |
| Labelliser / annoter | `k label pod <pod> tier=backend` · `k annotate ingress x clé=valeur --overwrite` |
| Patcher | `k patch svc skyboard-api -p '{"spec":{"selector":{"skyboard/slot":"green"}}}'` · `--patch-file patch.yaml` |
| Copier des fichiers | `k cp <pod>:/chemin ./local` |

## Diagnostiquer un Pod en 4 questions
1. `k get pod` : état ? `Pending` → `describe` (ressources, affinité, volume) · `ImagePullBackOff` → nom/tag/registry · `CrashLoopBackOff` → `logs --previous` · `Running` mais `0/1 READY` → readiness probe.
2. `k describe pod` : section **Events** en bas, toujours.
3. `k logs` (avec `--previous` si redémarrages).
4. `k exec`/`k debug` : le process écoute-t-il sur le bon port ? (`wget -qO- localhost:8000/healthz`).

## Réseau
`k get endpoints skyboard-api` (qui reçoit le trafic) · DNS : `<svc>.<ns>.svc.cluster.local` · depuis le toolbox : `nslookup skyboard-api` · `k get ingress` · `curl -H 'Host: skyboard.local' localhost/api/version`

## Helm & Kustomize
`helm install skyboard ./skyboard -n helm --create-namespace` · `helm upgrade skyboard ./skyboard --set image.api.tag=v2` · `helm rollback skyboard 1` · `helm history skyboard` · `helm template skyboard ./skyboard | less` · `helm lint ./skyboard`
`kubectl kustomize overlays/prod` (rendu) · `kubectl apply -k overlays/prod` · `kubectl kustomize overlays/prod | kubectl diff -f -`
