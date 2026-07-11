FROM ghcr.io/rake-pro/steamcmd-base:latest

LABEL maintainer="greg@rake.pro" \
      name="rake-pro/rust-server"

# unzip is needed to extract Oxide's release archive (a .zip); bookworm-slim
# doesn't ship it. Root only for this build layer - runtime user stays steam.
USER root
RUN apt-get update && apt-get install -y --no-install-recommends unzip \
 && rm -rf /var/lib/apt/lists/*

# Rust (Facepunch) dedicated server app id
ENV STEAMAPPID=258550 \
    INSTALL_DIR=/steamcmd/rust \
    SKIPUPDATE=false \
    RUST_BRANCH="" \
    RUST_SERVER_IDENTITY=docker \
    RUST_SERVER_STARTUP_ARGUMENTS="-batchmode -load -nographics +server.secure 1" \
    RUST_SERVER_PORT=28015 \
    RUST_SERVER_QUERYPORT="" \
    RUST_SERVER_SEED=12345 \
    RUST_SERVER_WORLDSIZE=3500 \
    RUST_SERVER_MAXPLAYERS=500 \
    RUST_SERVER_SAVE_INTERVAL=600 \
    RUST_SERVER_NAME="Rust Server [DOCKER]" \
    RUST_SERVER_DESCRIPTION="This is a Rust server running inside a Docker container!" \
    RUST_SERVER_URL="" \
    RUST_SERVER_BANNER_URL="" \
    RUST_SERVER_LEVELURL="" \
    RUST_APP_PORT=28082 \
    RUST_RCON_PORT=28016 \
    RUST_RCON_PASSWORD="" \
    RUST_RCON_WEB=1 \
    RUST_OXIDE_ENABLED=0 \
    RUST_CARBON_ENABLED=0

COPY --chown=steam:steam ./scripts /home/steam/server/

RUN chmod +x /home/steam/server/*.sh \
 && mkdir -p /steamcmd/rust \
 && chown -R steam:steam /steamcmd

WORKDIR /home/steam/server

# Process name confirmed by upstream docs: RustDedicated is the server binary.
HEALTHCHECK --start-period=5m \
            CMD pgrep -f RustDedicated > /dev/null || exit 1

USER steam

ENTRYPOINT ["/home/steam/server/init.sh"]
