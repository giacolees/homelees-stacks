# Retired services & archive

[← back to overview](../README.md)

## Retired reading services

Shelfarr and Grimmory were removed on 2026-11-04. Their library data is
retained at `/mnt/media/Grimmory`; their SSD app state (`/home/shelfarr`,
`/home/grimmory`) was archived on 2026-11-22 to
`/mnt/media/Archive/2026-11-22-rescue/retired-app-state-grimmory-shelfarr.tar.gz`
and deleted from the SSD.

## Archive (`/mnt/media/Archive`)

`2026-11-22-rescue/` holds the only files that were not already on
`/mnt/media` when the one-off `/home/media-backup` copy (Sept 2026) was
deleted: 10 Nextcloud photos (`admin/files/Amazon Photos Downloads/Immagini`),
the final Immich DB dump, the Immich removal tarball, and the
Grimmory/Shelfarr app state. Private stack
configuration copies (including secrets) are retained at
`/home/giacolees/retired-stacks-2026-11-04` with restricted permissions.

## Retired: Vita (wellness coach) — 2026-11-22

Stack removed (containers, images and `/opt/stacks/wellness` incl. its DB
files deleted). Port 3100 removed from `host/ports.txt` (firewall +
VPN forwards), landing page, Homepage, Caddy, Diun and the backup
job. Final DB dump + stack config (incl. secrets, 0600):
`/mnt/media/Archive/2026-11-22-vita/`. Source: GitHub `giacolees/my-wellness-coach`.

## Retired: Tailscale — 2026-11-23

Replaced by NetBird (HTTPS-only via Caddy + Authelia). Node logged out and
`tailscale` purged (apt repo + keyring removed); `tailscale-serve.service`,
`tailscale-remote-access.sh`, the `tailscale0`/UDP 41641 nftables rules, Cockpit's
`tailscale0` exception, the health-check/bot Tailscale status, `TS_*` site
values and the MagicDNS name in Homepage/Nextcloud/Cockpit/Ferdium were
removed. Devices not enrolled in NetBird reach the server only from the LAN.
