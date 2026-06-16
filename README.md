# minecraft-ctf

PaperMC server for the NAV Security Champions Minecraft hacking CTF.
Runs on NAIS (`appsec-ctf` namespace), world state persisted in a PVC.

## Repository structure

```
.
├── .github/workflows/deploy.yml        # build + deploy pipeline
├── .nais/
│   ├── minecraft-pvc.yaml              # PersistentVolumeClaim (deploy once)
│   └── minecraft.yaml                  # NAIS Application
├── server/
│   ├── server.properties               # baked into image — static server config
│   ├── paper-global.yml                # baked into image — PaperMC global config
│   ├── essentials-config.yml           # baked into image — EssentialsX config
│   ├── essentials-spawn.yml            # baked into image — EssentialsX spawn point
│   └── essentials-spawn-config.yml     # baked into image — EssentialsXSpawn config
├── Dockerfile
└── entrypoint.sh                       # first-boot seed logic + healthcheck server
```

## How it works

- On first pod start, `entrypoint.sh` copies PaperMC, plugins, and config from the image into the PVC (`/data`) and starts the server.
- On subsequent starts, `paper.jar` already exists so the seed step is skipped and the server starts from existing PVC state.
- `server.properties`, `paper-global.yml`, and EssentialsX configs are overwritten from the image on every boot — changes to those files must be made in the repo.
- EssentialsXSpawn teleports every player to the world spawn on join.
- Players connect in offline mode (no Mojang auth) — any username works. No players are OP'd.
- Cheat protections and anti-cheat are disabled — flight, exploits, and custom clients are allowed.

## Connecting (participants)

Port-forward the Minecraft port to your local machine:

```bash
kubectl port-forward -n appsec-ctf $(kubectl get pod -n appsec-ctf -l app=minecraft-ctf -o jsonpath='{.items[0].metadata.name}') 25565:25565
```

Then connect in Minecraft to `localhost:25565`.

## Deployment

**PVC** (once only — survives redeployments):
```bash
kubectl apply -f .nais/minecraft-pvc.yaml -n appsec-ctf
```

**Application** — push to `main`. The GitHub Actions workflow builds the image and deploys it automatically.

Watch startup logs:
```bash
kubectl logs -f deployment/minecraft-ctf -n appsec-ctf
# Wait for: Done (Xs)! For help, type "help"
```

## Uploading a world

Build the world in singleplayer (`mcworkshop`), then copy it to the server while it is running.
Use a staging folder to avoid corrupting the live world mid-copy:

```bash
POD=$(kubectl get pod -n appsec-ctf -l app=minecraft-ctf -o jsonpath='{.items[0].metadata.name}')

# Copy into staging folder
kubectl cp "/path/to/saves/mcworkshop/." "appsec-ctf/${POD}:/data/mcworkshop-new"

# Atomically swap and restart
kubectl exec -n appsec-ctf ${POD} -- bash -c \
  "rm -rf /data/mcworkshop && mv /data/mcworkshop-new /data/mcworkshop && kill \$(pgrep -f paper.jar)"
```

The server restarts automatically and loads the new world.

## PVC reset

Wipes all world state and re-seeds from the image on next boot:

```bash
kubectl scale deployment minecraft-ctf --replicas=0 -n appsec-ctf
kubectl delete pvc minecraft-ctf-data -n appsec-ctf
kubectl apply -f .nais/minecraft-pvc.yaml -n appsec-ctf
```

GitHub Actions will scale the deployment back up automatically on the next push, or scale it up manually:
```bash
kubectl scale deployment minecraft-ctf --replicas=1 -n appsec-ctf
```
