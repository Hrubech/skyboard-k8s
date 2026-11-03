# Logs et monitoring d'une application dans Kubernetes — fiche repère

Hors du périmètre strict du programme IF-KUBDEV, mais indispensable à un développeur : ce que l'application doit faire, ce que la plateforme fait pour elle, et où s'arrête la responsabilité du développeur.

## 1. Logs : la règle unique côté application

Écrire sur **stdout / stderr**, une ligne par événement, de préférence en **JSON** (horodatage, niveau, message, identifiant de requête, version). Rien dans des fichiers, aucune rotation à gérer : le runtime capture les flux, le kubelet les écrit dans `/var/log/pods/<ns>_<pod>_<uid>/<container>/`.

```bash
kubectl logs deploy/skyboard-api -f --all-containers --since=10m   # suivre
kubectl logs pod/skyboard-api-xxxx --previous                       # le container d'avant le crash
kubectl logs -l app.kubernetes.io/name=skyboard-api --prefix       # tous les réplicas, préfixés
stern skyboard-api                                                   # outil tiers : multi-pods en couleur
```

Pièges : un process qui logue dans un fichier du container perd tout au redémarrage ; un log multi-lignes (stack trace) doit être sérialisé sur une ligne ou reconnu par le parseur de l'agent.

## 2. Centralisation : le pattern DaemonSet

Un agent par nœud (DaemonSet) lit `/var/log/pods` via `hostPath`, enrichit chaque ligne avec les métadonnées Kubernetes (namespace, pod, labels) et expédie vers un stockage central. Le TP4 déploie un `node-agent` minimal qui joue exactement ce rôle ; en vrai :

| Rôle | Outils courants | Note |
| --- | --- | --- |
| Agent (collecte, parse, enrichit) | Fluent Bit, Vector, Promtail / Grafana Alloy, Filebeat | Léger, DaemonSet, configuré par ConfigMap |
| Stockage / recherche | Grafana Loki, Elasticsearch/OpenSearch, offres cloud | Loki indexe les labels, pas le texte : peu coûteux |
| Visualisation | Grafana, Kibana/OpenSearch Dashboards | Requêtes par labels Kubernetes : `{namespace="prod", app="skyboard-api"}` |

Alternative : le pattern **sidecar** (un second container dans le Pod qui lit un fichier partagé via `emptyDir`) pour une application legacy qu'on ne peut pas faire loguer sur stdout. Vu au TP2a (`02-pods/02-pod-sidecar.yaml`).

## 3. Métriques : deux niveaux à ne pas confondre

| Niveau | Source | Sert à | Dans la formation |
| --- | --- | --- | --- |
| Ressources (CPU, mémoire par Pod/nœud) | **metrics-server** (`kubectl top pods`) | HPA, diagnostic rapide | TP4 : l'HPA s'appuie dessus |
| Métriques applicatives (latence, erreurs, débit, files) | Endpoint `/metrics` exposé par l'application (format Prometheus/OpenMetrics) scrapé par **Prometheus** | Alerting, tableaux de bord, SLO | À ajouter dans votre code : bibliothèque client Prometheus (Python `prometheus_client`, Java Micrometer, .NET `prometheus-net`) |

Stack de référence : **Prometheus + Alertmanager + Grafana** (chart `kube-prometheus-stack`), ou **OpenTelemetry** (métriques + traces + logs avec un seul SDK, collecteur en DaemonSet ou Deployment). L'application expose, la plateforme collecte : le développeur n'installe pas Prometheus, il rend son service **observable**.

Les sondes (`/healthz`, `/readyz`) ne sont pas du monitoring : elles répondent à Kubernetes, pas aux humains. Mais un `/readyz` qui passe à faux est un signal à remonter aussi en métrique.

## 4. Événements et état : ce que Kubernetes dit déjà

```bash
kubectl get events --sort-by=.lastTimestamp -A      # ce qui s'est passé (pull, schedule, probes, OOM)
kubectl describe pod <pod>                            # état, raisons, derniers événements
kubectl top pods --containers                         # consommation instantanée
k9s                                                   # tout cela en une console
```

`OOMKilled`, `CrashLoopBackOff`, `FailedScheduling`, `Unhealthy` : quatre raisons qui expliquent 80 % des incidents applicatifs ; les lire dans les events avant d'ouvrir les logs.

## 5. Checklist « mon service est observable »

- [ ] Logs structurés sur stdout, avec niveau, horodatage, `request_id`, `version`
- [ ] Aucun secret ni donnée personnelle dans les logs
- [ ] `/metrics` exposé (ou SDK OpenTelemetry) avec au minimum : requêtes totales, erreurs, latence (histogramme)
- [ ] Sondes `/healthz` et `/readyz` distinctes et honnêtes
- [ ] `resources.requests/limits` renseignés : sans eux, pas d'alerte d'OOM pertinente ni d'HPA
- [ ] Labels `app.kubernetes.io/name` et `version` sur les Pods : ce sont eux qui serviront de filtres dans Grafana/Kibana

Pour aller plus loin : documentation officielle « Logging Architecture » et « Resource metrics pipeline » sur kubernetes.io ; CNCF landscape, section Observability.
