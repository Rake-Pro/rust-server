# rust-server

Rust (Facepunch) dedicated server image. Built on the shared
`ghcr.io/rake-pro/steamcmd-base` image and runs entirely as the nonroot
`steam` user. Supports optional Oxide/uMod or Carbon mod loading (mutually
exclusive). Published to GitHub Container Registry:

```
ghcr.io/rake-pro/rust-server
```

## Fork

This is a fork of [Didstopia/rust-server](https://github.com/Didstopia/rust-server)
(MIT, original copyright retained in `LICENSE.md`). What changed:

- Rebuilt `FROM ghcr.io/rake-pro/steamcmd-base`; the server runs entirely as
  the nonroot `steam` user instead of root.
- `RUST_RCON_PASSWORD` is required whenever RCON is enabled (`RUST_RCON_PORT`
  non-empty); no baked-in default password.
- Oxide and Carbon mod loading are mutually exclusive and validated at boot
  (the container exits with an error if both are enabled).
- Dropped upstream's heartbeat companion app, ad hoc `docker_run*.sh` /
  `docker_build*.sh` helper scripts, and GitHub issue/PR templates.
- Own semver release pipeline (`vX.Y.Z` git tags, Trivy-gated build; see
  Tags / releases) in place of upstream's build scripts.

## Base image

| Item | Value |
| --- | --- |
| Base | `ghcr.io/rake-pro/steamcmd-base:latest` (SteamCMD, the `steam` user, `gosu`, shared `/opt/scripts/functions.sh` helpers) |
| Runtime user | `steam` (nonroot) for the whole boot; no root phase in this image |
| Extra packages | `unzip` (to extract Oxide's release archive) |

## Tags / releases

| Tag | Meaning |
| --- | --- |
| `X.Y.Z` | Immutable release, built from git tag `vX.Y.Z` |
| `X.Y` | Latest patch of that minor |
| `latest` | Latest release |
| `sha-<short>` | Commit the image was built from |

- `dev` is the integration branch (default); `ci.yml` builds on every push and PR
  and publishes `:dev` / `:dev-<sha>` images on pushes to `dev`.
- `sync-main.yml` opens a promotion PR from `dev` to `main`. Merging it (merge
  commit) mints the next patch tag and `release.yml` builds, pushes and
  Trivy-scans the image (blocking on fixable CRITICALs).
- Label the promotion PR `release:minor` or `release:major` to change the bump.
- `trivy-rescan.yml` re-scans the currently released image weekly
  (CRITICAL+HIGH) so CVEs disclosed after release still surface; it does not
  rebuild or push anything.
- Pin `X.Y.Z` in deployments; `latest` is a convenience pointer.

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
`/steamcmd/rust/server/<RUST_SERVER_IDENTITY>`); this layout is unchanged
from the previous image so existing world data keeps working.

RCON is enabled by default (`RUST_RCON_PORT=28016`) and has no default
password. If RCON is enabled, `RUST_RCON_PASSWORD` must be set or the
container exits with an error at boot.

## Configuration

| Variable | Default | Required | Purpose |
| --- | --- | --- | --- |
| `SKIPUPDATE` | `false` | | Skip the SteamCMD update on boot (still installs if the binary is missing). |
| `RUST_BRANCH` | (empty) | | Steam beta branch to install (e.g. `staging`); empty/`public` = default branch. Mapped onto the base image's `STEAM_BETA` internally; update retries/failure handling come from the base's `steamcmd_update` helper. |
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
| `RUST_RCON_PASSWORD` | (none) | **yes, if RCON enabled** | RCON password. No default; required whenever `RUST_RCON_PORT` is non-empty. |
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

## License

MIT (original Didstopia copyright retained), see `LICENSE.md`.
