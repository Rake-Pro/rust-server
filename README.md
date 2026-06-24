# rust-server

Rust dedicated server image (SteamCMD-based, with a web RCON UI and optional
Oxide/uMod). Originally derived from Didstopia/rust-server (MIT); maintained here
and published to GitHub Container Registry as `ghcr.io/rake-pro/rust-server`.

```
ghcr.io/rake-pro/rust-server
```

## Run

```
docker run -d --name rust \
  -p 28015:28015/udp -p 28016:28016/udp -p 28082:28082/udp -p 8080:8080/tcp \
  -e RUST_SERVER_NAME="My Rust Server" \
  -e RUST_RCON_PASSWORD=change-me \
  -e RUST_SERVER_WORLDSIZE=3500 \
  -e RUST_SERVER_MAXPLAYERS=100 \
  -e PUID=1000 -e PGID=1000 \
  -v /path/to/data:/steamcmd/rust \
  ghcr.io/rake-pro/rust-server:latest
```

On boot the server installs/updates via SteamCMD (Rust app id `258550`),
optionally installs Oxide, then launches. The world and saves persist under the
`/steamcmd/rust` volume.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `RUST_SERVER_NAME` | `Rust Server [DOCKER]` | Public server name. |
| `RUST_SERVER_IDENTITY` | `docker` | Save directory name. |
| `RUST_SERVER_SEED` | `12345` | Map seed (ignored if a level URL is set). |
| `RUST_SERVER_WORLDSIZE` | `3500` | Procedural map size. |
| `RUST_SERVER_MAXPLAYERS` | `500` | Player cap. |
| `RUST_SERVER_PORT` | `28015` | Game port. |
| `RUST_SERVER_STARTUP_ARGUMENTS` | `-batchmode -load -nographics +server.secure 1` | Extra RustDedicated launch flags (e.g. `+server.levelurl`). |
| `RUST_RCON_PORT` / `RUST_RCON_PASSWORD` | `28016` / `docker` | RCON endpoint and password. |
| `RUST_RCON_WEB` | `1` | Serve the web RCON UI (nginx on `8080`). |
| `RUST_APP_PORT` | `28082` | Rust+ companion app port. |
| `RUST_OXIDE_ENABLED` / `RUST_OXIDE_UPDATE_ON_BOOT` | `0` / `1` | Install Oxide/uMod and update it on boot. |
| `RUST_UPDATE_CHECKING` | `0` | Auto-check for server updates and restart. |
| `RUST_START_MODE` | `0` | `0` update+start, `1` update only, `2` start only. |
| `PUID` / `PGID` | `1000` | UID/GID that owns files on the volume. |

## Ports

| Port | Use |
| --- | --- |
| `28015/udp` | Game server. |
| `28016/udp` | RCON / query. |
| `28082/udp` | Rust+ companion app. |
| `8080/tcp` | Web RCON UI. |

## Volumes

| Path | Use |
| --- | --- |
| `/steamcmd/rust` | Game install + world saves (persist this). |
