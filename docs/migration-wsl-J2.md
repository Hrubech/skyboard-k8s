# Migration WSL2 — séquence du matin J2 (20 min, 9h00-9h20)

Contexte : le J1 s'est fait sur des VM instables ; le J2 repart sur **WSL2 Ubuntu** du poste de chaque stagiaire.
Tout ce qui a été fait au J1 est reconstruit en une commande (`make checkpoint-2b`), le stagiaire ne refait pas les TP.

## Ce que le formateur fait la veille (par VNC, 7 postes, ~8 min chacun si le réseau suit)

Sur chaque poste, dans PowerShell de la session du stagiaire :
```powershell
wsl -l -v                                   # Ubuntu en VERSION 2 ; sinon : wsl --set-version Ubuntu 2
notepad $env:USERPROFILE\.wslconfig         # [wsl2] memory=12GB processors=4 swap=4GB  → wsl --shutdown
```
Puis dans Ubuntu :
```bash
cat /etc/wsl.conf                           # [boot] systemd=true ; sinon l'ajouter puis wsl --shutdown
git clone https://github.com/Hrubech/skyboard-k8s.git && cd skyboard-k8s
bash 00-poste/check-network.sh && bash 00-poste/install.sh
```
Fermer/rouvrir Ubuntu, puis `cd skyboard-k8s && make check && make cluster && make images && make preload && make checkpoint-2b && make status`.
Résultat attendu : 3 nœuds Ready, Deployment `skyboard-api` 3/3, Service `skyboard-api`, Pod `toolbox`.
Si fait la veille, la séquence du matin se réduit à l'étape 4 ci-dessous (5 min).

## Séquence du matin si rien n'a pu être préparé (20 min)

**9h00 — À dire** : « Hier, l'environnement nous a fait perdre du temps. Ce matin, on repart sur WSL, l'Ubuntu intégré
à votre poste Windows : plus de VM, plus d'hyperviseur, et le navigateur de votre poste voit directement le cluster.
Vingt minutes, tout le monde ensemble, puis on retrouve exactement l'état de fin de J1 en une commande. »

**9h02 — Étape 1, PowerShell (2 min)** — tout le monde tape en même temps, je partage mon écran :
```powershell
wsl -l -v
```
Ubuntu en VERSION 2 attendu. Un stagiaire en VERSION 1 ou sans Ubuntu : `wsl --install -d Ubuntu` (redémarrage du poste
possible → il passe sur le plan C navigateur pour la matinée, poste traité à la pause).

**9h04 — Étape 2, Ubuntu (3 min)** :
```bash
cat /etc/wsl.conf ; systemctl is-system-running
```
Si pas de `systemd=true` : `printf '[boot]\nsystemd=true\n' | sudo tee /etc/wsl.conf`, puis dans PowerShell `wsl --shutdown`, rouvrir Ubuntu.

**9h07 — Étape 3, installation en tâche de fond (10 min, pendant lesquelles je fais le réveil pédagogique)** :
```bash
git clone https://github.com/Hrubech/skyboard-k8s.git && cd skyboard-k8s && bash 00-poste/check-network.sh && bash 00-poste/install.sh
```
Consigne : « Laissez tourner, ne touchez plus à ce terminal. On fait les questions flash pendant ce temps. »
Formateur : surveiller par VNC les 7 terminaux ; un `KO` dans `check-network.sh` = le signaler dans le chat, continuer.

**9h17 — Étape 4, reconstruction de l'état de J1 (3 min)** — fermer le terminal Ubuntu, le rouvrir (groupe docker) :
```bash
cd skyboard-k8s && make check && make cluster && make images && make checkpoint-2b && make status
```
Critère : `make status` montre 3 nœuds Ready et `skyboard-api` 3/3. **À dire** : « Vous êtes exactement là où nous
étions hier à 17h10. TP3a dans dix minutes. »

`make preload` (toutes les images des TP suivants) se lance ensuite en tâche de fond pendant l'exposé M3 : « lancez
`make preload &` et laissez-le travailler ».

## Ce qui change pour les stagiaires par rapport à la VM

| Avant (VM) | Maintenant (WSL2) |
| --- | --- |
| Console de l'hyperviseur ou SSH vers une IP | Terminal Ubuntu de Windows (ou Windows Terminal), VS Code avec l'extension WSL |
| `http://<ip-vm>` depuis le navigateur | `http://localhost`, `http://localhost:8081`, `http://localhost:30080` — automatiquement |
| `skyboard.local` dans le hosts de la VM | Dans WSL : fait par `install.sh`. Dans le navigateur Windows : `127.0.0.1 skyboard.local` dans `C:\Windows\System32\drivers\etc\hosts` (droits admin) ; sans droits, `curl -H 'Host: skyboard.local' localhost` dans WSL suffit pour tous les TP |
| Clipboard aléatoire | Copier-coller natif depuis le cahier PDF |

## Pièges connus WSL2

- **`/etc/hosts` régénéré à chaque démarrage de WSL** : les noms `k3d-registry.localhost` et `skyboard.local` disparaissent et `docker push` échoue (`no such host`). `install.sh` écrit `[network] generateHosts=false` dans `/etc/wsl.conf` ; sur un poste installé avant ce correctif : `printf '\n[network]\ngenerateHosts=false\n' | sudo tee -a /etc/wsl.conf` puis relancer `install.sh`.
- **WSL s'arrête quelques secondes après la fermeture du dernier terminal** et le cluster avec lui (il redémarre seul à la réouverture, compter 60 s) : garder un terminal ouvert, ou `vmIdleTimeout=-1` sous `[wsl2]` dans `.wslconfig`.

- **Docker Desktop installé sur le poste** : désactiver son intégration WSL pour « Ubuntu » (Settings → Resources → WSL integration), sinon deux démons Docker se disputent la socket.
- **Port 80 déjà pris côté Windows** (IIS, Skype, un autre service) : `make cluster` échoue sur le mapping 80 → éditer `01-cluster/k3d-config.yaml`, remplacer `80:80` par `8080:80`, et tester les Ingress sur `localhost:8080`.
- **Mémoire** : sans `.wslconfig`, WSL prend 50 % de la RAM ; avec 8 Go de poste cela fait 4 Go, trop juste pour 3 nœuds + HPA → `.wslconfig` à 6 Go minimum, ou cluster à 1 agent (`agents: 1` dans `k3d-config.yaml`, les affinités passent alors en démo).
- **Horloge WSL décalée après une mise en veille** (certificats, pulls en erreur) : `sudo hwclock -s` ou `wsl --shutdown`.
- **`wsl --shutdown` arrête le cluster** : il redémarre tout seul à la prochaine ouverture d'Ubuntu (containers k3d en `unless-stopped`) ; attendre `k get nodes` Ready.
