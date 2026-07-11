# rust-server

Rust (Facepunch) dedicated server image. Built on the shared
`ghcr.io/rake-pro/steamcmd-base` image and runs entirely as the nonroot
`steam` user. Supports optional Oxide/uMod or Carbon mod loading (mutually
exclusive). Published to GitHub Container Registry:

```
ghcr.io/rake-pro/rust-server
```

## Tags / releases

CI (`.github/workflows/build.yml`) versions the image as semver:

- Every push to `main` mints a patch-bumped `vX.Y.Z` git tag (`#major` /
  `#minor` in the commit message bump those segments) and pushes
  `vX.Y.Z` + `latest` to GHCR. No `sha-` tags on main builds.
- The version tag and the image push happen only after the Trivy scan gate
  passes (blocking on fixable CRITICALs; a HIGH+CRITICAL report also runs,
  non-blocking).
- PR builds are build+scan only (short-sha tag, never pushed).
- Pin `vX.Y.Z` in deployments; `latest` is a convenience pointer.

## Run

```
docker run -d --name rust \
  -p 28015:28015/udp -p 28016:28016/tcp -p 28082:28082/udp \
  -e RUST_SERVER_NAME="My Rust Server" \
  -e RUST_RCON_PASSWORD=<set-your-own-password> \
  -e RUST_SERVER_WORLDSIZE=3500 \
  -e RUST_SERVER_MAXPLAYERS=100 \
  -v /path/to/data:/steamcmd \
  ghcr.io/rake-pro/rust-server:latest
```

On boot the server installs/updates via SteamCMD (app id `258550`) unless
`SKIPUPDATE=true`, optionally installs Oxide or Carbon, then launches
`RustDedicated`. The world and saves persist under the `/steamcmd` volume
(install at `/steamcmd/rust`, identity saves at
`/steamcmd/rust/server/<RUST_SERVER_IDENTITY>`) - this layout is unchanged
from the previous image so existing world data keeps working.

RCON is enabled by default (`RUST_RCON_PORT=28016`) and has no default
password. If RCON is enabled, `RUST_RCON_PASSWORD` must be set or the
container exits with an error at boot.

## Configuration

| Variable | Default | Required | Purpose |
| --- | --- | --- | --- |
| `SKIPUPDATE` | `false` | | Skip the SteamCMD update on boot (still installs if the binary is missing). |
| `RUST_BRANCH` | (empty) | | Steam beta branch to install (e.g. `staging`); empty/`public` = default branch. |
| `RUST_SERVER_IDENTITY` | `docker` | | Save directory name under `/steamcmd/rust/server/`. |
| `RUST_SERVER_NAME` | `Rust Server [DOCKER]` | | Public server name. |
| `RUST_SERVER_DESCRIPTION` | (default text) | | Server description. |
| `RUST_SERVER_URL` | (empty) | | Server website URL. |
| `RUST_SERVER_BANNER_URL` | (empty) | | Server header image URL. |
| `RUST_SERVER_SEED` | `12345` | | Map seed (ignored if `RUST_SERVER_LEVELURL` is set). |
| `RUST_SERVER_WORLDSIZE` | `3500` | | Procedural map size. |
| `RUST_SERVER_LEVELURL` | (empty) | | Custom map download URL; overrides seed/worldsize. |
| `RUST_SERVER_MAXPLAYERS` | `500` | | Player cap. |
| `RUST_SERVER_SAVE_INTERVAL` | `600` | | Autosave interval, seconds. |
| `RUST_SERVER_PORT` | `28015` | | Game port. |
| `RUST_SERVER_QUERYPORT` | (empty) | | Steam query port (empty = engine default). |
| `RUST_SERVER_STARTUP_ARGUMENTS` | `-batchmode -load -nographics +server.secure 1` | | Extra raw `RustDedicated` launch flags. |
| `RUST_RCON_PORT` | `28016` | | RCON port. Set empty to disable RCON entirely. |
| `RUST_RCON_PASSWORD` | (none) | **yes, if RCON enabled** | RCON password. No default - required whenever `RUST_RCON_PORT` is non-empty. |
| `RUST_RCON_WEB` | `1` | | Enable RustDedicated's native websocket RCON protocol. |
| `RUST_APP_PORT` | `28082` | | Rust+ companion app port. |
| `RUST_OXIDE_ENABLED` | `0` | | Install/update Oxide (uMod) at boot. Exclusive with `RUST_CARBON_ENABLED`. |
| `RUST_CARBON_ENABLED` | `0` | | Install/update Carbon at boot. Exclusive with `RUST_OXIDE_ENABLED`. |

## Ports

| Port | Use |
| --- | --- |
| `28015/udp` | Game server. Also used for the Steam query port unless `RUST_SERVER_QUERYPORT` sets a separate one. |
| `28016/tcp` | RCON. |
| `28082/udp` | Rust+ companion app (if used). |

## Volumes

| Path | Use |
| --- | --- |
| `/steamcmd` | PVC mount root. Game install lives at `/steamcmd/rust`, world saves at `/steamcmd/rust/server/<identity>`. Persist this whole path. |

## Oxide vs Carbon

Only one mod framework may be enabled at a time. Setting both
`RUST_OXIDE_ENABLED=1` and `RUST_CARBON_ENABLED=1` causes the container to
log an error and exit 1 at boot. Each is downloaded fresh from its official
release URL over HTTPS on every boot when enabled (no version pinning); the
resolved version is logged.
