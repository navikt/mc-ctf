#!/bin/bash
set -euo pipefail

DATA=/data
MC_VERSION="${MC_VERSION:-1.21.11}"

# ── First-boot seeding ────────────────────────────────────────────────────────
# The PVC starts empty. On first boot we copy the baked-in artifacts from /app.
# On subsequent boots the jar and config already exist and we skip this block.

if [ ! -f "${DATA}/paper.jar" ]; then
    echo "[entrypoint] First boot — seeding /data from image..."

    mkdir -p "${DATA}"
    cp /app/paper.jar "${DATA}/paper.jar"

    mkdir -p "${DATA}/cache"
    cp /app/cache/mojang_${MC_VERSION}.jar "${DATA}/cache/mojang_${MC_VERSION}.jar"

    mkdir -p "${DATA}/plugins"
    cp /app/plugins/*.jar "${DATA}/plugins/"

    mkdir -p "${DATA}/plugins/EssentialsXSpawn"
    cp /app/essentials-spawn-config.yml "${DATA}/plugins/EssentialsXSpawn/config.yml"

    echo "eula=true" > "${DATA}/eula.txt"

    echo "[entrypoint] Seeding complete."
fi

# ── Always overwrite static config from image ─────────────────────────────────
# These files are baked into the image and should always reflect the image's
# settings, not whatever is cached on the PVC.
cp /app/server.properties "${DATA}/server.properties"
mkdir -p "${DATA}/config"
cp /app/paper-global.yml "${DATA}/config/paper-global.yml"
mkdir -p "${DATA}/plugins/Essentials"
cp /app/essentials-config.yml "${DATA}/plugins/Essentials/config.yml"

# ── Healthcheck HTTP server ───────────────────────────────────────────────────
# NAIS liveness/readiness probes expect HTTP 200 on port 8080.
# python3 -m http.server responds 200 to any GET — no extra dependencies needed.
echo "[entrypoint] Starting healthcheck server on :8080..."
python3 -m http.server 8080 --directory "${DATA}" &

# ── PaperMC ───────────────────────────────────────────────────────────────────
echo "[entrypoint] Starting PaperMC ${MC_VERSION}..."
cd "${DATA}"
exec java ${JAVA_OPTS:--Xms1G -Xmx2G} \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -jar paper.jar --nogui
