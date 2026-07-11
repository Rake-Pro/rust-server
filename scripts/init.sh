#!/bin/bash
# shellcheck source=/dev/null
source /opt/scripts/functions.sh

# INSTALL_DIR and the identity subdirectory are PVC-backed (mounted at
# /steamcmd by the chart). Keep this exact layout - force_install_dir
# /steamcmd/rust with identity saves under /steamcmd/rust/server/<identity> -
# so existing world saves from the previous image keep working.
mkdir -p "$INSTALL_DIR" "$INSTALL_DIR/server/$RUST_SERVER_IDENTITY"

# Rust ships its own steamclient.so; point the loader at it.
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$INSTALL_DIR/RustDedicated_Data/Plugins/x86_64"

# Install/update on boot unless skipped. Always install if the binary is
# missing - e.g. a freshly provisioned or wiped PVC.
if [ "$SKIPUPDATE" != "true" ]; then
    LogInfo "Installing/updating Rust (app id $STEAMAPPID)..."
    if [ -n "$RUST_BRANCH" ] && [ "$RUST_BRANCH" != "public" ]; then
        LogInfo "Using beta branch: $RUST_BRANCH"
        /home/steam/steamcmd/steamcmd.sh \
            +force_install_dir "$INSTALL_DIR" \
            +login anonymous \
            +app_update "$STEAMAPPID" -beta "$RUST_BRANCH" validate \
            +quit
    else
        /home/steam/steamcmd/steamcmd.sh \
            +force_install_dir "$INSTALL_DIR" \
            +login anonymous \
            +app_update "$STEAMAPPID" validate \
            +quit
    fi
elif [ ! -x "$INSTALL_DIR/RustDedicated" ]; then
    LogWarn "SKIPUPDATE=true but RustDedicated is missing; installing anyway"
    /home/steam/steamcmd/steamcmd.sh \
        +force_install_dir "$INSTALL_DIR" \
        +login anonymous \
        +app_update "$STEAMAPPID" validate \
        +quit
else
    LogWarn "SKIPUPDATE=true, not updating the game"
fi

if [ ! -x "$INSTALL_DIR/RustDedicated" ]; then
    LogError "Install finished but $INSTALL_DIR/RustDedicated is missing"
    exit 1
fi

# Oxide and Carbon are mutually exclusive mod frameworks.
if [ "$RUST_OXIDE_ENABLED" = "1" ] && [ "$RUST_CARBON_ENABLED" = "1" ]; then
    LogError "RUST_OXIDE_ENABLED and RUST_CARBON_ENABLED cannot both be 1 - pick one"
    exit 1
fi

if [ "$RUST_OXIDE_ENABLED" = "1" ]; then
    LogInfo "Installing/updating Oxide (uMod)..."
    OXIDE_URL="https://umod.org/games/rust/download/develop"
    OXIDE_TMP="$(mktemp -d)"
    if ! curl -fsSL -A "Mozilla/5.0" "$OXIDE_URL" -o "$OXIDE_TMP/oxide.zip"; then
        LogError "Failed to download Oxide from $OXIDE_URL"
        exit 1
    fi
    if ! unzip -oq "$OXIDE_TMP/oxide.zip" -d "$INSTALL_DIR"; then
        LogError "Failed to extract Oxide archive"
        exit 1
    fi
    rm -rf "$OXIDE_TMP"
    OXIDE_VERSION="unknown"
    if [ -f "$INSTALL_DIR/RustDedicated_Data/Managed/Oxide.Rust.dll" ]; then
        OXIDE_VERSION="$(strings "$INSTALL_DIR/RustDedicated_Data/Managed/Oxide.Rust.dll" 2>/dev/null | grep -m1 -E '^[0-9]+\.[0-9]+\.[0-9]+$' || echo unknown)"
    fi
    LogInfo "Oxide installed (resolved version: $OXIDE_VERSION)"
fi

if [ "$RUST_CARBON_ENABLED" = "1" ]; then
    LogInfo "Installing/updating Carbon..."
    CARBON_URL="https://github.com/CarbonCommunity/Carbon/releases/latest/download/Carbon.Linux.Release.tar.gz"
    CARBON_TMP="$(mktemp -d)"
    if ! curl -fsSL "$CARBON_URL" -o "$CARBON_TMP/carbon.tar.gz"; then
        LogError "Failed to download Carbon from $CARBON_URL"
        exit 1
    fi
    if ! tar -xzf "$CARBON_TMP/carbon.tar.gz" -C "$INSTALL_DIR"; then
        LogError "Failed to extract Carbon archive"
        exit 1
    fi
    rm -rf "$CARBON_TMP"
    CARBON_VERSION="unknown"
    if [ -f "$INSTALL_DIR/carbon/version.json" ]; then
        CARBON_VERSION="$(grep -m1 -oE '"InformationalVersion"[[:space:]]*:[[:space:]]*"[^"]+"' "$INSTALL_DIR/carbon/version.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^"]*' || echo unknown)"
    fi
    LogInfo "Carbon installed (resolved version: $CARBON_VERSION)"
fi

# RCON is on by default (RUST_RCON_PORT has a default). Require an explicit
# password whenever it's enabled - no baked-in default password.
RCON_ARGS=()
if [ -n "$RUST_RCON_PORT" ]; then
    require_env RUST_RCON_PASSWORD
    RCON_ARGS+=("+rcon.port" "$RUST_RCON_PORT")
    RCON_ARGS+=("+rcon.password" "$RUST_RCON_PASSWORD")
    [ -n "$RUST_RCON_WEB" ] && RCON_ARGS+=("+rcon.web" "$RUST_RCON_WEB")
fi

# Build the RustDedicated argument list from env vars.
add_argument_pair() {
    local -n arr="$1"
    local flag="$2"
    local value="$3"
    [ -n "$value" ] && arr+=("$flag" "$value")
}

ARGUMENTS=()
add_argument_pair ARGUMENTS "+server.port" "$RUST_SERVER_PORT"
add_argument_pair ARGUMENTS "+server.queryport" "$RUST_SERVER_QUERYPORT"
add_argument_pair ARGUMENTS "+server.identity" "$RUST_SERVER_IDENTITY"

if [ -n "$RUST_SERVER_LEVELURL" ]; then
    LogInfo "Using custom map: $RUST_SERVER_LEVELURL"
    add_argument_pair ARGUMENTS "+server.levelurl" "$RUST_SERVER_LEVELURL"
else
    LogInfo "Generating procedural map (seed $RUST_SERVER_SEED, worldsize $RUST_SERVER_WORLDSIZE)"
    add_argument_pair ARGUMENTS "+server.worldsize" "$RUST_SERVER_WORLDSIZE"
    add_argument_pair ARGUMENTS "+server.seed" "$RUST_SERVER_SEED"
fi

add_argument_pair ARGUMENTS "+server.hostname" "$RUST_SERVER_NAME"
add_argument_pair ARGUMENTS "+server.url" "$RUST_SERVER_URL"
add_argument_pair ARGUMENTS "+server.headerimage" "$RUST_SERVER_BANNER_URL"
add_argument_pair ARGUMENTS "+server.description" "$RUST_SERVER_DESCRIPTION"
add_argument_pair ARGUMENTS "+server.maxplayers" "$RUST_SERVER_MAXPLAYERS"
add_argument_pair ARGUMENTS "+server.saveinterval" "$RUST_SERVER_SAVE_INTERVAL"
add_argument_pair ARGUMENTS "+app.port" "$RUST_APP_PORT"

# shellcheck disable=SC2206
STARTUP_ARGS=($RUST_SERVER_STARTUP_ARGUMENTS)

# Log to stdout (so `docker logs` / `kubectl logs` capture it) unless the
# caller already set their own -logfile in RUST_SERVER_STARTUP_ARGUMENTS.
if [[ ! " ${STARTUP_ARGS[*]} " == *" -logfile "* ]]; then
    STARTUP_ARGS+=("-logfile" "/dev/stdout")
fi

term_handler() {
    LogInfo "Caught SIGTERM, stopping server"
    kill -SIGTERM "$child" 2>/dev/null
    wait "$child"
}
trap 'term_handler' SIGTERM

LogInfo "Starting RustDedicated..."
cd "$INSTALL_DIR" || exit 1
./RustDedicated "${STARTUP_ARGS[@]}" "${ARGUMENTS[@]}" "${RCON_ARGS[@]}" &
child=$!
wait "$child"
