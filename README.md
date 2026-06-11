# minecraft-ctf

PaperMC server for the NAV Security Champions Minecraft hacking CTF.
Runs on NAIS (appsec namespace), world state persisted in a PVC.

## Repository structure

```
.
├── .github/workflows/deploy.yml        # build + deploy pipeline
├── .nais/
│   ├── minecraft-pvc.yaml              # PersistentVolumeClaim (deploy once)
│   └── minecraft.yaml                  # NAIS Application + LoadBalancer Service
├── server/
│   ├── server.properties               # baked into image — static server config
│   └── essentials-spawn-config.yml     # baked into image — EssentialsXSpawn config
├── Dockerfile
└── entrypoint.sh                       # first-boot seed logic + healthcheck server
```

## How it works

- On first pod start, `entrypoint.sh` downloads PaperMC, copies plugins and config into the PVC (`/data`), and starts the server.
- On subsequent starts, `/data/paper.jar` already exists so the seed step is skipped and the server starts directly from the existing PVC state.
- EssentialsXSpawn teleports every player to world spawn on join, so everyone always lands in the bedrock box.
- Players connect in offline mode (no Mojang auth) — Fabric dev clients launched from IntelliJ work out of the box.
- The server is only reachable from the internal network via the LoadBalancer Service.

## First-time setup

**1. Deploy the PVC** (once only — it survives redeployments):
```bash
kubectl apply -f .nais/minecraft-pvc.yaml -n ctf
```

**2. Push to `main`** — the GitHub Actions workflow builds the image and deploys the Application.

**3. Watch the first-boot log** until PaperMC finishes generating the world:
```bash
kubectl logs -f deployment/minecraft-ctf -n ctf
# Wait for: Done (Xs)! For help, type "help"
```

**4. Get the external IP** for players to connect to:
```bash
kubectl get svc minecraft-ctf-tcp -n ctf
# Use the EXTERNAL-IP value — may take a minute to provision
```

**5. Set world spawn inside the bedrock box** (once, via server console):
```bash
kubectl exec -it deployment/minecraft-ctf -n ctf -- \
  java -cp /data/paper.jar io.papermc.paperclip.Main --nogui
```
> Note: PaperMC console stdin isn't easily accessible via kubectl exec.
> Use RCON (see below) or run these as startup commands via a Paper config.

Via RCON or any OP'd player in-game:
```
/setworldspawn 0 65 0
/gamerule spawnRadius 0
/gamerule doMobSpawning false
/gamerule doWeatherCycle false
```

## RCON

Add to `server.properties` to enable RCON (rebuild and redeploy):
```properties
enable-rcon=true
rcon.password=changeme
rcon.port=25575
```

Then exec into the pod and use `mcron` or any RCON client pointed at `localhost:25575`.

## World reset

### Soft reset — wipe world only, keep plugins and config
```bash
kubectl exec -n ctf deployment/minecraft-ctf -- \
  rm -rf /data/world /data/world_nether /data/world_the_end
kubectl rollout restart deployment/minecraft-ctf -n ctf
```

### Hard reset — full re-seed from image
```bash
kubectl scale deployment minecraft-ctf --replicas=0 -n ctf
kubectl delete pvc minecraft-ctf-data -n ctf
kubectl apply -f .nais/minecraft-pvc.yaml -n ctf
kubectl scale deployment minecraft-ctf --replicas=1 -n ctf
```

## Accessing the PVC directly (upload world files, plugins, etc.)

```bash
# 1. Scale down — ReadWriteOnce allows only one pod to hold the volume
kubectl scale deployment minecraft-ctf --replicas=0 -n ctf

# 2. Spin up a temporary access pod
kubectl run pvc-access \
  --image=ubuntu:24.04 \
  --restart=Never \
  --namespace=ctf \
  --overrides='{
    "spec": {
      "containers": [{
        "name": "pvc-access",
        "image": "ubuntu:24.04",
        "command": ["sleep", "3600"],
        "volumeMounts": [{"mountPath": "/data", "name": "mc-data"}]
      }],
      "volumes": [{"name": "mc-data", "persistentVolumeClaim": {"claimName": "minecraft-ctf-data"}}]
    }
  }'

kubectl wait pod/pvc-access -n ctf --for=condition=Ready --timeout=60s

# 3. Copy files in or out
kubectl cp ./world/ ctf/pvc-access:/data/world        # upload pre-built world
kubectl cp ctf/pvc-access:/data/world ./world-backup/ # download world backup

# 4. Clean up and bring the server back
kubectl delete pod pvc-access -n ctf
kubectl scale deployment minecraft-ctf --replicas=1 -n ctf
```