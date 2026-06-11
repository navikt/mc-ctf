FROM eclipse-temurin:25-jre-noble

ARG MC_VERSION=1.21.11

RUN apt-get update && apt-get install -y --no-install-recommends curl jq python3 \
    && rm -rf /var/lib/apt/lists/*

# Download PaperMC at build time using the fill API.
RUN DOWNLOAD_URL=$(curl -fsSL -H "User-Agent: nais-minecraft-ctf/1.0" \
      "https://fill.papermc.io/v3/projects/paper/versions/${MC_VERSION}/builds" \
      | jq -r 'map(select(.channel == "STABLE")) | .[0] | .downloads."server:default".url') && \
    echo "Downloading PaperMC from: ${DOWNLOAD_URL}" && \
    mkdir -p /app && \
    curl -fsSL -o /app/paper.jar "${DOWNLOAD_URL}"

# Download EssentialsX core and Spawn module.
# Both are required — EssentialsXSpawn depends on EssentialsX core.
RUN mkdir -p /app/plugins && \
    curl -fsSL -o /app/plugins/EssentialsX.jar \
      "https://github.com/EssentialsX/Essentials/releases/download/2.22.0/EssentialsX-2.22.0.jar" && \
    curl -fsSL -o /app/plugins/EssentialsXSpawn.jar \
      "https://github.com/EssentialsX/Essentials/releases/download/2.22.0/EssentialsXSpawn-2.22.0.jar"

# Bake in static server config, plugin config, and entrypoint.
# World state is managed at runtime via the PVC (/data).
COPY --chown=1069:1069 server/server.properties /app/server.properties
COPY --chown=1069:1069 server/essentials-spawn-config.yml /app/essentials-spawn-config.yml
COPY --chown=1069:1069 entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# NAIS runs containers as uid 1069 by default.
# /data is the PVC mountpoint — writable at runtime, not present at build time.
# /tmp is an emptyDir — writable. Everything else is read-only.
USER 1069

ENTRYPOINT ["/entrypoint.sh"]
