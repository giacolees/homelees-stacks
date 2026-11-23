# Jellyfin

[← back to overview](../../README.md)

## Jellyfin (media server)

Adopted from the orphaned CasaOS container into a managed stack.

- Stack: `/opt/stacks/jellyfin/compose.yaml`
- Image: `linuxserver/jellyfin:12.1ubu2604-ls50` (version-pinned)
- Config: `/DATA/AppData/jellyfin/config` (outside git)
- Media: `/mnt/media` (the 18TB disk) mounted into the container at `/media`
- Secret: `/opt/stacks/jellyfin/.env` (`OPENAI_API_KEY`, gitignored, mode 0600)
- Ports: bound to `192.168.1.70` + `127.0.0.1` only; DLNA on the LAN address.
  Remote access is via NetBird -> `https://jellyfin.homelees.party` (Caddy -> `127.0.0.1:8096`).
- Firewall: `docker-published-firewall.service` drops non-LAN traffic to all
  published Docker UI ports (8096 included) in `DOCKER-USER`. The built-in
  HTTPS port 8920 is no longer published (removed 2026-11-22; unused).

### Commands

```bash
cd /opt/stacks/jellyfin
sudo docker compose config
sudo docker compose ps
sudo docker compose logs -f --tail=100
sudo docker compose pull && sudo docker compose up -d    # update
sudo docker compose down                                 # stop/remove
```

First run: open `http://192.168.1.70:8096` (LAN) or `https://jellyfin.homelees.party` and complete
the setup wizard.

### Media library

Media lives on the 18TB disk, stably mounted at `/mnt/media` and bind-mounted
into the container as `/media`. Jellyfin libraries:

| Library   | Container path       |
|-----------|----------------------|
| Movies    | `/media/Movies`      |
| TV Shows  | `/media/TV Shows`    |
| Music     | `/media/Music`       |
| Books     | `/media/Books`       |
| Images    | `/media/Images`      |
| Videos    | `/media/Videos`      |

General (non-Jellyfin) storage lives on the same disk:

| Purpose  | Host path              | Container path    |
|----------|------------------------|-------------------|
| Datasets | `/mnt/media/Datasets`  | `/media/Datasets` |

Full layout on the 18TB disk:

```
/mnt/media/
├── Books/        # Jellyfin "Books" library (flat PDFs/EPUBs at top level)
│   ├── ingest/   #   Shelfmark downloads -> CWA ingest (emptied after import)
│   └── library/  #   Calibre library managed by CWA (served over OPDS)
├── Datasets/     # datasets / general storage (not a Jellyfin library)
├── Downloads/    # qBittorrent / SABnzbd download area
├── Grimmory/     # Retained library data from retired Grimmory service
├── Images/       # Jellyfin "Photos" library
├── Movies/       # Jellyfin "Movies" library
├── Music/        # Jellyfin "Music" library
├── Nextcloud/    # Nextcloud user data
├── TV Shows/     # Jellyfin "Shows" library
└── Videos/       # Jellyfin "Home Videos" library
```

Files must be readable/writable by UID/GID `1000` (the disk is `chown`ed to
`1000:1000`, matching Jellyfin's `PUID`/`PGID`).
