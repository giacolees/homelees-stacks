# Downloads (*arr + VPN)

[← back to overview](../../README.md)

## Downloads / *arr stack

The "click to request, and it lands in the right folder" flow:

    Seerr (requests stack) -> Sonarr / Radarr -> qBittorrent (via Gluetun VPN)
                                              \-> SABnzbd (Usenet)
    Prowlarr -> FlareSolverr (Cloudflare / DDoS-GUARD bypass, internal only)
    Bazarr -> subtitles (movies/TV)

- Stack: `/opt/stacks/downloads/compose.yaml`
- Request UI (**Seerr**) is **not** here; it runs in its own
  `/opt/stacks/requests` stack, reaching Sonarr/Radarr over `downloads_default`
  and Jellyfin over `media_net`.
- Secrets: `/opt/stacks/downloads/.env` (VPN credentials, gitignored)
- State: `/opt/stacks/downloads/config/<app>` (gitignored)
- All apps mount the 18TB disk at `/data` (same filesystem as the libraries, so
  Sonarr/Radarr **hardlink** imports instead of copying).
- FlareSolverr (Cloudflare / DDoS-GUARD bypass for Prowlarr) has **no published
  port**; Prowlarr reaches it internally at `http://flaresolverr:8191`.

| App         | Purpose                   | Host port | HTTPS name |
|-------------|---------------------------|-----------|-------------|
| Prowlarr    | Indexer manager           | 9696      | `prowlarr` |
| Sonarr      | TV automation             | 8989      | `sonarr` |
| Radarr      | Movies automation         | 7878      | `radarr` |
| Bazarr      | Subtitles                 | 6767      | `bazarr` |
| qBittorrent | Torrents (behind Gluetun) | 8080      | `torrent` |
| SABnzbd     | Usenet                    | 8081      | `sab` |
| Shelfmark   | Ebook search & download (behind Gluetun) | 8084 | `shelfmark` |

### VPN (Gluetun) — required

qBittorrent shares Gluetun's network namespace, so its traffic can only leave
through the VPN (kill switch). Edit `/opt/stacks/downloads/.env`, set your
provider and credentials (see
<https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers>), then:

```bash
sudo docker compose -f /opt/stacks/downloads/compose.yaml up -d
```

Until then, `gluetun` and `qbittorrent` stay stopped; all other apps run.
Deploying the `downloads` stack from Komodo will also try to start them.

### Folder mapping

- Downloads: `/data/Downloads/...` = `/mnt/media/Downloads/...`
- Sonarr root folder: `/data/TV Shows` = `/mnt/media/TV Shows`
- Radarr root folder: `/data/Movies` = `/mnt/media/Movies`
- Inside the stack, qBittorrent is at host `gluetun:8080`; SABnzbd at `sabnzbd:8080`.

### One-time setup order

1. Complete the Jellyfin setup wizard, then create an API key.
2. **Prowlarr**: add indexers, then Settings -> Apps -> add Sonarr & Radarr.
   Add the Cloudflare solver under Settings -> Indexers -> Add Indexer ->
   FlareSolverr (host `http://flaresolverr:8191`, tag `flaresolverr`).
3. **qBittorrent** (after the VPN is up): set the admin password.
4. **Sonarr**: add root folder `/data/TV Shows`; add qBittorrent (host `gluetun`,
   port `8080`) as a download client.
5. **Radarr**: root folder `/data/Movies`; add qBittorrent.
6. **SABnzbd**: add your Usenet server; add it as a download client in Sonarr/Radarr.
7. **Bazarr**: add languages + subtitle providers; connect Sonarr/Radarr.
8. **Seerr** (`requests` stack): sign in with Jellyfin, connect Sonarr/Radarr.
9. In Jellyfin, scan libraries so imported media appears.
