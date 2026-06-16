FROM eclipse-temurin:25-jre-noble

ARG MC_VERSION=1.21.11

RUN apt-get update && apt-get install -y --no-install-recommends curl jq python3 \
    && rm -rf /var/lib/apt/lists/*

# Download PaperMC at build time using the fill API.
# The API response includes a SHA256 checksum — verify before accepting the jar.
RUN mkdir -p /app && \
    curl -fsSL -H "User-Agent: nais-minecraft-ctf/1.0" \
      "https://fill.papermc.io/v3/projects/paper/versions/${MC_VERSION}/builds" \
      -o /tmp/paper-builds.json && \
    DOWNLOAD_URL=$(jq -r 'map(select(.channel == "STABLE")) | .[0] | .downloads."server:default".url' /tmp/paper-builds.json) && \
    EXPECTED_SHA=$(jq -r 'map(select(.channel == "STABLE")) | .[0] | .downloads."server:default".checksums.sha256' /tmp/paper-builds.json) && \
    echo "Downloading PaperMC from: ${DOWNLOAD_URL}" && \
    curl -fsSL -o /app/paper.jar "${DOWNLOAD_URL}" && \
    echo "${EXPECTED_SHA}  /app/paper.jar" | sha256sum -c - && \
    rm /tmp/paper-builds.json

# Download EssentialsX core and Spawn module.
# Both are required — EssentialsXSpawn depends on EssentialsX core.
# Checksums computed from the 2.22.0 release artifacts.
RUN mkdir -p /app/plugins && \
    curl -fsSL -o /app/plugins/EssentialsX.jar \
      "https://github.com/EssentialsX/Essentials/releases/download/2.22.0/EssentialsX-2.22.0.jar" && \
    echo "bda4685105977fca2e209820a9f0ad24275bd103390a03236f38e59bfdac58e6  /app/plugins/EssentialsX.jar" | sha256sum -c - && \
    curl -fsSL -o /app/plugins/EssentialsXSpawn.jar \
      "https://github.com/EssentialsX/Essentials/releases/download/2.22.0/EssentialsXSpawn-2.22.0.jar" && \
    echo "dd5377c4c921b9b67814209f4f6646ffbb959729003e721ec5e63c47c7c010b8  /app/plugins/EssentialsXSpawn.jar" | sha256sum -c -

# Bake in static server config, plugin config, and entrypoint.
# World state is managed at runtime via the PVC (/data).
COPY --chown=1069:1069 server/server.properties /app/server.properties
COPY --chown=1069:1069 server/paper-global.yml /app/paper-global.yml
COPY --chown=1069:1069 server/essentials-spawn-config.yml /app/essentials-spawn-config.yml
COPY --chown=1069:1069 entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# NAIS runs containers as uid 1069 by default.
# /data is the PVC mountpoint — writable at runtime, not present at build time.
# /tmp is an emptyDir — writable. Everything else is read-only.
USER 1069

ENTRYPOINT ["/entrypoint.sh"]
