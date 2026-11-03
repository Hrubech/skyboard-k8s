# Raccourcis du dépôt SkyBoard. `make help` liste les cibles.
.DEFAULT_GOAL := help
TPS := 1 2a 2b 3a 3b 4 5 6 7 atelier

help:           ## Affiche cette aide
	@grep -E '^[a-zA-Z0-9_%-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-22s %s\n", $$1, $$2}'

check:          ## Vérifie le poste (outils, ressources, réseau)
	@00-poste/check.sh

cluster:        ## Crée le cluster k3d (TP1)
	@01-cluster/create.sh

images:         ## Construit et pousse skyboard-api v1/v2 et skyboard-web dans la registry k3d
	@app/api/build.sh && app/web/build.sh

preload:        ## Pré-charge toutes les images des TP dans le cluster (J-1)
	@00-poste/preload-images.sh

status:         ## Vue d'ensemble : nœuds, pods, services, ingress
	@kubectl get nodes -o wide && echo && kubectl get deploy,sts,ds,job,cronjob,hpa,svc,ingress -A --field-selector metadata.namespace!=kube-system 2>/dev/null || kubectl get all

$(addprefix checkpoint-,$(TPS)): ## checkpoint-<tp> : restaure l'état de fin du TP (1 2a 2b 3a 3b 4 5 6 7 atelier)
	@checkpoints/restore.sh $(subst checkpoint-,,$@)

clean-apps:     ## Supprime les objets SkyBoard (garde le cluster)
	@kubectl delete -k 07-kustomize/overlays/dev --ignore-not-found 2>/dev/null || true
	@kubectl delete -k 07-kustomize/overlays/prod --ignore-not-found 2>/dev/null || true
	@helm uninstall skyboard -n helm 2>/dev/null || true
	@helm uninstall ingress-nginx -n ingress-nginx 2>/dev/null || true
	@kubectl delete all,ingress,cm,secret,pvc,hpa,pc -l app.kubernetes.io/part-of=skyboard --ignore-not-found
	@kubectl delete ns legacy dev prod helm ingress-nginx --ignore-not-found

clean:          ## Détruit le cluster k3d et la registry
	@k3d cluster delete skyboard
