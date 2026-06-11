#!/bin/bash
set -euo pipefail

DATA=/data
MC_VERSION="${MC_VERSION:-1.21.11}"
PAPERMC_API="https://fill.papermc.io/v3/projects/paper/versions/${MC_VERSION}/builds"

# ── First-boot seeding ────────────────────────────────────────────────────────
# The PVC starts empty. On first boot we download PaperMC and copy in config.
# On subsequent boots the jar and config already exist and we skip this block.

if [ ! -f "${DATA}/paper.jar" ]; then
    echo "[entrypoint] First boot — seeding /data from image and PaperMC API..."

    # Fetch the latest stable build URL from the PaperMC fill API
    DOWNLOAD_URL=$(curl -fsSL -H "User-Agent: nais-minecraft-ctf/1.0" "${PAPERMC_API}" \
        | jq -r 'map(select(.channel == "STABLE")) | .[0] | .downloads."server:default".url')

    if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" = "null" ]; then
        echo "[entrypoint] ERROR: could not resolve stable PaperMC download URL for ${MC_VERSION}"
        exit 1
    fi

    echo "[entrypoint] Downloading PaperMC from: ${DOWNLOAD_URL}"
    curl -fsSL -o "${DATA}/paper.jar" "${DOWNLOAD_URL}"

    # Static server config (baked into image)
    cp /app/server.properties "${DATA}/server.properties"

    # Plugins — jars baked into image, config seeded from image
    mkdir -p "${DATA}/plugins"
    cp /app/plugins/*.jar "${DATA}/plugins/"

    mkdir -p "${DATA}/plugins/EssentialsXSpawn"
    cp /app/essentials-spawn-config.yml "${DATA}/plugins/EssentialsXSpawn/config.yml"

    # Accept EULA
    echo "eula=true" > "${DATA}/eula.txt"

    echo "[entrypoint] Seeding complete."
fi

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
