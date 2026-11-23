# Music (Navidrome + Octo-Fiesta)

[← back to overview](../../README.md)

## Navidrome & Octo-Fiesta (Music Streaming + Subsonic Proxy)

Low-latency, Spotify-like self-hosted music stack split across two companion
services:
- **Navidrome** (`/opt/stacks/navidrome`) for core Subsonic/OpenSubsonic
  library indexing and web playback (`:4533`). Point native Subsonic clients
  (**Sonora** on macOS, **Amperfy** / **Narjo** on iOS, **Symfonium**, etc.)
  directly at `:4533`.
- **Octo-Fiesta** (`/opt/stacks/octo-fiesta`) as a Subsonic proxy that fills
  library gaps from Deezer (`:5275`).

Both services store their databases, caches, and the shared music library
on the fast NVMe SSD (`/home/navidrome/music`, mounted at `/data` in all
containers) so playback starts with 0 ms disk spin-up delay and paths match 1:1
without remote path mappings.

> **Retired: Octo (`winters27/octo`, port 5274).** Removed 2026-11-17. It was
> shut down 2026-11-10 and superseded by Octo-Fiesta; its Last.fm scrobbling
> role moved to Navidrome itself. Containers, `navidrome_net` peer, port 5274
> (firewall + VPN forward), landing-page row, Homepage entry, the
> `/home/octo` data directory and the `/opt/stacks/octo` stack were all removed.
> History is in git (`git log --all -- octo/`).

### Navidrome

- URL (LAN): http://192.168.1.70:4533
- URL (HTTPS, LAN + NetBird): `https://music.homelees.party`
- Image: `deluan/navidrome:0.64.2` (pinned in `.env`)
- App data, SQLite DB & transcode/image caches: `/home/navidrome/data` -> `/config` (SSD)
- Music library (read-only mount): `/home/navidrome/music` -> `/data:ro` (SSD)
- Port 4533 is bound to LAN + loopback and filtered by
  `docker-published-firewall.service`; remote access is via NetBird -> Caddy (`https://<name>.homelees.party`)
- **ListenBrainz scrobbling** (migrated from Last.fm on 2026-11-20):
  `ND_LISTENBRAINZ_ENABLED=true` is set in `compose.yaml` (Last.fm API keys
  removed). Each user enables *Settings → Personal → Scrobble to ListenBrainz*
  with their ListenBrainz User Token (`ListenBrainzSessionKey` in `user_props`).
  Navidrome is the scrobbler — Octo-Fiesta has no scrobbling support.
- **Backfilling missed plays**: Navidrome records every play in its own
  `scrobbles` table, so plays made while scrobbling was unconfigured are not
  lost. `/home/giacolees/scripts/listenbrainz-backfill.py` replays them
  (dry-run by default, `--commit` to send, `--lastfm-export` to merge a
  Last.fm export) and dedupes against the user's existing ListenBrainz history.
  2026-11-20: 1,418 plays migrated for `giacolees` (Last.fm `giava2005` +
  Navidrome DB) and 201 plays for `valees` (Navidrome DB).

```bash
cd /opt/stacks/navidrome
sudo docker compose config
sudo docker compose ps
sudo docker compose logs -f --tail=100
sudo docker compose pull && sudo docker compose up -d   # update
```

### Octo-Fiesta

`V1ck3s/octo-fiesta` is a Subsonic API proxy that, when a requested track is
missing from Navidrome, fetches it
from Deezer, tags it, and writes it into the library so Navidrome indexes it as
a normal song. No radio/mixes/YouTube — it only fills library gaps.

- URL (LAN): http://192.168.1.70:5275
- URL (HTTPS, LAN + NetBird): `https://subsonic.homelees.party`
- Image (pinned via `OCTO_FIESTA_TAG=b6a48b8` in `.env` — GHCR only publishes
  `latest`, `dev` and commit-SHA tags, so a SHA is the only way to pin):
  - `ghcr.io/v1ck3s/octo-fiesta:b6a48b8` (v0.11)
- Storage (all on NVMe SSD `/home`):
  - Shared music library (`:rw`, same `/data` path Navidrome indexes): `/home/navidrome/music` -> `/data`
  - App config / future Tidal token store: `/home/octo-fiesta/config` -> `/config`
- Key settings in `.env`:
  - `MUSIC_SERVICE=Deezer`, `DEEZER_QUALITY=FLAC` (needs `DEEZER_ARL`)
  - `STORAGE_MODE=Permanent` (tracks land in the library permanently)
  - `DOWNLOAD_MODE=Track` (only the requested track, not the whole album)
  - `FOLDER_TEMPLATE={artist}/{album}/{track} - {title}` — `{track}` is
    zero-padded to 2 digits, matching the existing library layout
  - `ENABLE_EXTERNAL_PLAYLISTS=true` — `.m3u` files land in `/data/playlists/`
    and Navidrome imports them
- Network: joins `navidrome_default` (`Subsonic__Url=http://navidrome:4533`)
- Port 5275 is bound to LAN + loopback and filtered by
  `docker-published-firewall.service`; remote access is via NetBird -> Caddy (`https://<name>.homelees.party`)
- `SUBSONIC_ADMIN_*` is empty, so new downloads appear on Navidrome's
  `@every 5m` scan rather than immediately. Set the admin creds to make
  octo-fiesta trigger a scan right after each download.
- Runs as **root** (upstream image has no `USER`), so downloaded files are
  `root:root` inside the library. Navidrome reads them fine; add
  `user: "1000:1000"` to the service if you want them owned by `giacolees`.
- **Single writer:** Octo-Fiesta is the only service writing into
  `/home/navidrome/music` other than manual imports (the retired Octo stack was
  the previous second writer).

```bash
cd /opt/stacks/octo-fiesta
sudo docker compose config
sudo docker compose ps
sudo docker compose logs -f --tail=100
sudo docker compose pull && sudo docker compose up -d   # update
# Tidal only: interactive OAuth login, tokens persist in /home/octo-fiesta/config
sudo docker compose run --rm octo-fiesta --tidal-login
```
