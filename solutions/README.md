# Solutions — à partager en fin de session

Cette branche ajoute le dossier `solutions/` à `main`. Les réponses aux **questions** du cahier
(Question 1, 2, …) et les erreurs typiques sont dans le document « Corrigés des TP et notes formateur » ;
ici ne figurent que les fichiers des exercices à compléter et la solution commentée de l'atelier.

| Exercice | Fichier solution | Ce qui change |
| --- | --- | --- |
| TP7 Kustomize — `skyboard-web` à 2 réplicas en prod | `07-kustomize/overlays/prod/replicas-resources.yaml` (patch stratégique) ou `kustomization-json6902.yaml` (variante JSON6902) | Un second document YAML dans le patch, ou une entrée `patches` ciblant le Deployment web |
| TP7 Helm — `terminationGracePeriodSeconds` paramétrable | `07-helm/skyboard/values.yaml` + `templates/api-deployment.yaml` | Nouvelle clé `api.terminationGracePeriodSeconds` (défaut 20), lue dans le template |
| Atelier J3 — blue/green puis canary | `08-atelier/SOLUTION.md` | Les 12 commandes dans l'ordre, ce qu'on observe, et le retour arrière |

Pour appliquer une solution : copiez le fichier à la place de l'original (`cp solutions/07-kustomize/overlays/prod/replicas-resources.yaml 07-kustomize/overlays/prod/`), puis relancez la commande du cahier.
