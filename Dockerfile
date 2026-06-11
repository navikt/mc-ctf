FROM eclipse-temurin:25-jre-noble

RUN apt-get update && apt-get install -y --no-install-recommends curl jq \
    && rm -rf /var/lib/apt/lists/*

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
