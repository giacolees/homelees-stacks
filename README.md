# /opt/stacks — Docker Compose stacks (primary CLI)

This directory holds self-hosted app stacks for **homelees** (Debian 12).
**`docker compose` is the primary management interface.** Komodo is the web UI
that reads/writes the same stacks (it replaced Dockge).

> Jellyfin was previously running as an orphaned CasaOS container. It has been
> adopted into a managed stack at `jellyfin/compose.yaml`, preserving its
> image, volumes and environment. Data lives in `/DATA/AppData/jellyfin`.

---

## Directory layout

```
/opt/stacks/
├── README.md                 # this file
├── .gitignore                # keeps credentials/state out of git
├── jellyfin/                 # media server (adopted from CasaOS)
│   ├── compose.yaml
│   └── .env                  # OPENAI_API_KEY (gitignored, mode 0600)
├── downloads/                # *arr acquisition stack + Gluetun VPN
│   ├── compose.yaml
│   ├── .env                  # VPN credentials (gitignored)
│   └── config/               # per-app state (gitignored)
├── homepage/                 # dashboard (links to every app)
│   ├── compose.yaml
│   └── config/               # services.yaml, settings.yaml, widgets.yaml
├── nextcloud/                # files/photos/calendar
│   ├── compose.yaml
│   └── .env                  # DB/admin passwords (gitignored)
├── immich/                   # photo & video library (mobile backup)
│   ├── compose.yaml
│   ├── .env                  # DB password (gitignored, mode 0600)
│   └── .env.example          # committed template with placeholders
└── <app>/                    # one directory per stack
    ├── compose.yaml          # canonical stack definition (preferred name)
    ├── .env                  # OPTIONAL, per-stack secrets — NEVER committed
    └── .env.example          # OPTIONAL, committed template with dummy values

/home/giacolees/komodo/       # Komodo (build/deploy web UI) - outside this repo
├── mongo.compose.yaml        # Komodo Core + Periphery + MongoDB
├── compose.env               # Core/Periphery config + secrets (mode 0600)
└── backups/                  # scheduled Komodo DB backups

/opt/dockge/                  # retired Dockge install (stopped, kept for rollback)
├── compose.yaml              # `docker compose up -d` here restores Dockge
└── data/                     # old Dockge state (root:root, mode 0700)
```

Conventions:
- One directory per app under `/opt/stacks/`, file named `compose.yaml`.
- Keep named volumes / bind mounts for persistent app data **outside git**
  (e.g. `/DATA/<app>`), or ignore them in `.gitignore`.
- Compose files should be self-contained; put secrets in `.env` (ignored).

## Ownership & permissions

| Path                     | Owner          | Mode  | Notes                                    |
|--------------------------|----------------|-------|------------------------------------------|
| `/opt/stacks`            | giacolees:giacolees | 2775 | setgid + default ACLs for agent editing  |
| `/opt/stacks/<app>`      | giacolees:giacolees | 2775 | created by the admin user                |
| `/opt/dockge`            | giacolees:giacolees | 0755 | retired Dockge install                   |
| `/opt/dockge/data`       | root:root      | 0700  | old Dockge secrets; root-only            |
| `/home/giacolees/komodo` | giacolees:giacolees | 0755 | Komodo compose + config                  |
| `.../komodo/compose.env` | giacolees:giacolees | 0600 | Komodo secrets; root-only-ish            |
| `/var/run/docker.sock`   | root:docker    | 0660  | root-equivalent access                   |

`/opt/stacks` uses a setgid bit and a **default ACL** so files created by root
(for example when Komodo/Periphery writes files) remain editable by the
`giacolees` user. If a stack somehow ends up root-owned:

```bash
sudo chown -R giacolees:giacolees /opt/stacks/<app>
```

### Why not add my user to the `docker` group?

The `docker` group is **not** enabled for `giacolees`. Membership grants
**root-equivalent access** (you can mount the host filesystem into a container,
so `docker run -v /:/host` is a trivial root escalation). Instead, run Docker
commands through `sudo`, which is already passwordless for this account.

If you ever accept that risk:

```bash
sudo usermod -aG docker giacolees   # then log out/in
# revert with: sudo gpasswd -d giacolees docker
```

---

## Prerequisites (already installed)

- Docker Engine `docker-ce` 29.8.1
- Docker Compose plugin `docker-compose-plugin` v5.5.1 (`docker compose`)
- Docker data lives on the SSD, **not** the small `/var` partition:
  `/etc/docker/daemon.json` sets `data-root: /home/docker`, and
  `/etc/containerd/config.toml` sets `root = /home/containerd`.
  (This moved `/var` from 93% to ~9% used.)

Verify:

```bash
docker compose version
sudo systemctl is-active docker
```

## Daily operations

All `docker` commands need root (no docker group), so prefix with `sudo`.
Run from the stack directory so `compose.yaml` and its `.env` are picked up.

```bash
cd /opt/stacks/<app>

# Validate before applying
sudo docker compose config

# Start / update
sudo docker compose up -d

# Status
sudo docker compose ps

# Stop (keeps containers + named volumes)
sudo docker compose stop

# Remove containers + networks (keeps named volumes)
sudo docker compose down

# Remove everything including named volumes (DESTRUCTIVE)
sudo docker compose down -v
```

### Add a new stack (no sample apps are installed by default)

```bash
mkdir -p /opt/stacks/myapp && cd /opt/stacks/myapp
# write compose.yaml (pin image tags), then:
sudo docker compose config
sudo docker compose up -d
```

## Log inspection

```bash
cd /opt/stacks/<app>
sudo docker compose logs -f --tail=100          # all services, follow
sudo docker compose logs -f --tail=100 <svc>    # one service
sudo docker logs --tail=200 <container_name>    # raw container log
sudo journalctl -u docker --since "1 hour ago"  # daemon-level issues
```

## Updates

Pin explicit image tags (avoid `:latest` where possible).

```bash
cd /opt/stacks/<app>
sudo docker compose pull
sudo docker compose up -d          # recreates only changed services
sudo docker image prune -f         # optional: remove dangling images
```

No automatic update mechanism is installed (no Watchtower, no unattended
upgrades). Updates are manual by design.

## Rollback

Compose files are tracked in git in this directory.

```bash
cd /opt/stacks
git log --oneline -- <app>/compose.yaml     # find the previous revision
git show <commit>:<app>/compose.yaml        # review it
git checkout <commit> -- <app>/compose.yaml # restore that revision
cd <app>
sudo docker compose config
sudo docker compose up -d
```

Image rollback (when a new image tag broke something):

```bash
cd /opt/stacks/<app>
# edit compose.yaml and pin the previous image tag/digest
sudo docker compose pull
sudo docker compose up -d
```

Rollback to Dockge (retired):

Dockge is stopped but its compose file and state are intact at `/opt/dockge/`
(outside this git repo). To fall back:

```bash
cd /opt/dockge
sudo docker compose config
sudo docker compose up -d
```

Do not then deploy the same stack from both Dockge and Komodo.

## Git & credentials

`/opt/stacks` is a git repo. `.gitignore` excludes `.env`, key material, and
common state directories. **Never commit credentials, tokens, `.env` files,
private keys, or Komodo's `compose.env` / Dockge's `data/`.** Commit only
compose files and `.env.example` templates with placeholder values.

```bash
cd /opt/stacks
git status
git add <app>/compose.yaml
git commit -m "add <app> stack"
```

---

## Homepage (dashboard)

One page listing every app — no need to remember IP:port. Config is YAML under
`/opt/stacks/homepage/config` (tracked in git). Secrets are not stored there:
the Komodo widget's API key/secret live in the gitignored
`/opt/stacks/homepage/.env` and reach the container as `HOMEPAGE_VAR_KOMODO_*`.

- URL (LAN): http://192.168.1.70:3000
- URL (tailnet): http://homelees-1.lungfish-pike.ts.net:3000
- Stack: `/opt/stacks/homepage/compose.yaml`

All card links use `HOMEPAGE_VAR_HOST` (set in `compose.yaml`), currently the
Tailscale MagicDNS name so they work from anywhere. To use LAN-IP links instead,
set `HOMEPAGE_VAR_HOST=192.168.1.70` and restart the stack.

Add/edit apps in `config/services.yaml`; layout/groups in `config/settings.yaml`.
`config/bookmarks.yaml` is an explicit empty list (`[]`) to suppress Homepage's
default Developer/Social/Entertainment examples.

### Server status (Glances)

A small `glances` container provides real **host** stats (CPU, RAM, disk,
uptime) for the `glances` info widget in `config/widgets.yaml`. It runs with
`pid: host` and mounts the host root (`/host`, read-only) and the media disk
(`/mnt/media`, read-only), so it reports the actual filesystems. It has **no
published port** and no Docker socket — only Homepage reaches it, over the
internal Docker network.

The dashboard shows CPU, memory, uptime, and disk usage for `/host`,
`/host/var`, and `/mnt/media`.

After editing any config, regenerate Homepage's cached static HTML:
```bash
curl -X POST http://127.0.0.1:3000/api/revalidate
```
(or click the refresh icon in the bottom-right of the dashboard).

Homepage runs **without** the Docker socket, to avoid exposing root-equivalent
access through an unauthenticated UI.

```bash
cd /opt/stacks/homepage
sudo docker compose config
sudo docker compose up -d
sudo docker compose logs -f --tail=100
sudo docker compose pull && sudo docker compose up -d   # update
```

## Komodo (build & deploy UI)

Komodo manages the same `/opt/stacks` directory as the CLI (Files-on-Host
mode), plus containers, builds and git-based deploys. It replaced Dockge.

- URL (LAN): **http://192.168.1.70:9120**
- URL (tailnet): `http://homelees-1.lungfish-pike.ts.net:9120`
- Stack: `/home/giacolees/komodo/mongo.compose.yaml` (Core + Periphery + Mongo)
- Config/secrets: `/home/giacolees/komodo/compose.env` (mode 0600)
- Admin login: created on first launch; credentials in `compose.env`
  (`KOMODO_INIT_ADMIN_USERNAME` / `KOMODO_INIT_ADMIN_PASSWORD`)

Komodo runs **three containers**: `komodo-core` (UI/API on :9120),
`komodo-periphery` (agent that runs compose/builds on the host) and
`komodo-mongo` (state). Periphery's root directory is `/opt`, mounted into the
container at the same path, which is why it can see `/opt/stacks`. It also
mounts `/var/run/docker.sock`.

Imported stacks use `files_on_host = true`,
`run_directory = /opt/stacks/<name>`, `auto_pull = false`, and the correct
`project_name` (the `wellness` directory maps to project `my-wellness-coach`).

### Access control

The UI is **not exposed to the public Internet**:

1. Core binds `0.0.0.0:9120`, so a `DOCKER-USER` rule drops tcp/9120 from any
   source outside `192.168.1.0/24` (the tailnet address included, so remote
   access goes through `tailscale serve`). All published Docker UI ports are
   managed together by `docker-published-firewall.service`:
   ```bash
   sudo iptables -S DOCKER-USER | grep 9120
   systemctl status docker-published-firewall.service
   ```
2. Remote access is via `tailscale serve` -> `127.0.0.1:9120` (listed in
   `/usr/local/sbin/tailscale-remote-access.sh`).

To allow a VPN subnet or add a new UI port, edit `LAN`/`PORTS` in
`/usr/local/sbin/docker-published-firewall.sh` (and the tailscale script) and
run `sudo systemctl restart docker-published-firewall.service`.

Komodo/Periphery mount `/var/run/docker.sock` (root-equivalent) and therefore
must be treated as an admin tool. Anyone who can reach :9120 and log in can
control Docker. Keep it on the LAN/VPN.

### Komodo lifecycle

```bash
cd /home/giacolees/komodo
sudo docker compose -p komodo -f mongo.compose.yaml --env-file compose.env ps
sudo docker compose -p komodo -f mongo.compose.yaml --env-file compose.env up -d
sudo docker compose -p komodo -f mongo.compose.yaml --env-file compose.env logs -f --tail=100
# update: pull newer images and recreate
sudo docker compose -p komodo -f mongo.compose.yaml --env-file compose.env pull
sudo docker compose -p komodo -f mongo.compose.yaml --env-file compose.env up -d
```

The Homepage dashboard shows a Komodo widget (server/stack/container counts).
Its API key/secret live in `/opt/stacks/homepage/.env` (gitignored) and reach
the container as `HOMEPAGE_VAR_KOMODO_KEY` / `HOMEPAGE_VAR_KOMODO_SECRET`.
Create a new key with:
`sudo docker exec komodo-core-1 km create api-key --for admin <name>`.

## Cockpit (host management UI)

- URL: **https://192.168.1.70:9090** (self-signed certificate — accept the
  browser warning)
- Installed from Debian as **system packages** (not a container): `cockpit`,
  `cockpit-system`, `cockpit-networkmanager`, `cockpit-packagekit`,
  `cockpit-storaged`.
- Login uses system PAM accounts (use the `giacolees` account and its password).

### Access control

1. `cockpit.socket` is bound to the LAN address only via
   `/etc/systemd/system/cockpit.socket.d/listen.conf`
   (`ListenStream=192.168.1.70:9090`, packaged default cleared). Verify:
   ```bash
   systemctl show cockpit.socket -p Listen
   sudo ss -tlnp | grep 9090      # should show 192.168.1.70:9090 only
   ```
2. Because Cockpit is a host service, it is filtered by the normal `INPUT`
   chain. `cockpit-firewall.service` drops tcp/9090 from any source outside
   `192.168.1.0/24` (loopback excepted), which also blocks router
   port-forwarding:
   ```bash
   sudo iptables -S INPUT
   systemctl status cockpit-firewall.service
   ```
   To also allow a VPN subnet, edit `LAN` in
   `/usr/local/sbin/cockpit-firewall.sh` and run
   `sudo systemctl restart cockpit-firewall.service`.

### Lifecycle

```bash
sudo systemctl status cockpit.socket
sudo systemctl restart cockpit.socket
sudo apt-get update && sudo apt-get install --only-upgrade cockpit
```

Cockpit generates a self-signed certificate (`CN=homelees`, 1-year validity).
For a trusted certificate, put Cockpit behind the existing Apache reverse proxy
or install a real certificate. Note: Cockpit does **not** ship a Docker module
in Debian; Docker Compose management is done with the CLI and Komodo.

## Tailscale (remote access VPN)

Tailscale is installed as a system service (`tailscaled`) from the official
Debian repo. It gives the server a private WireGuard-based address on your
tailnet so you can reach it from anywhere without opening router ports.

- CLI: `tailscale`
- Daemon: `tailscaled.service` (enabled)
- Status: `sudo tailscale status`

### First-time login (manual, one-off)

```bash
sudo tailscale up --ssh --accept-dns=false
```

Open the printed URL and authenticate. `--ssh` enables Tailscale SSH (log in
from any of your tailnet devices with your tailnet identity; the normal sshd
on port 22 is unchanged). `--accept-dns=false` leaves the server's own DNS
alone.

### Remote access to the web UIs

Cockpit stays bound to the LAN **and loopback only**, and Komodo's published
port is firewalled to the LAN. `tailscale serve` forwards tailnet traffic to
loopback, so nothing new is exposed on the LAN or the public Internet:

| Service     | Tailnet URL |
|-------------|-------------|
| Cockpit     | `https://<node>.<tailnet>.ts.net:9090` (self-signed cert warning) |
| Komodo      | `http://<node>.<tailnet>.ts.net:9120` |
| Jellyfin    | `http://<node>.<tailnet>.ts.net:8096` |
| Homepage    | `http://<node>.<tailnet>.ts.net:3000` |
| Nextcloud   | `http://<node>.<tailnet>.ts.net:8082` |
| Immich      | `http://<node>.<tailnet>.ts.net:2283` |
| Jellyseerr  | `http://<node>.<tailnet>.ts.net:5055` |
| Prowlarr    | `http://<node>.<tailnet>.ts.net:9696` |
| Sonarr      | `http://<node>.<tailnet>.ts.net:8989` |
| Radarr      | `http://<node>.<tailnet>.ts.net:7878` |
| Bazarr      | `http://<node>.<tailnet>.ts.net:6767` |
| qBittorrent | `http://<node>.<tailnet>.ts.net:8080` |
| SABnzbd     | `http://<node>.<tailnet>.ts.net:8081` |

`tailscale-serve.service` waits for login and applies the config
automatically. To re-apply manually:

```bash
sudo /usr/local/sbin/tailscale-remote-access.sh
sudo tailscale serve status
```

### Firewall interaction

`/usr/local/sbin/cockpit-firewall.sh` now allows the `tailscale0` interface and
loopback in addition to `192.168.1.0/24`; everything else to tcp/9090 is
dropped (chain `COCKPIT-FW`). Docker-published ports (Komodo and the app UIs)
are **not** reachable directly over Tailscale — only through `tailscale serve`.

### Optional: reach the whole LAN

To let tailnet devices reach other LAN hosts (not just this server), enable IP
forwarding and advertise the subnet, then approve the route in the Tailscale
admin console:

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf
sudo sysctl --system
sudo tailscale set --advertise-routes=192.168.1.0/24
```

### Lifecycle / updates

```bash
sudo tailscale status
sudo tailscale netcheck
sudo apt-get update && sudo apt-get install --only-upgrade tailscale
sudo tailscale logout        # disconnect (also revoke in the admin console)
```

### Security notes

- Tailscale traffic is end-to-end encrypted (WireGuard) and authenticated by
  your identity provider.
- The server's public SSH (port 22) is unchanged; consider restricting it to
  the LAN/tailnet later if you want.
- Tailscale is a third-party control plane (free tier). For full self-hosting,
  the same role can be filled by WireGuard or Headscale.

## Jellyfin (media server)

Adopted from the orphaned CasaOS container into a managed stack.

- Stack: `/opt/stacks/jellyfin/compose.yaml`
- Image: `linuxserver/jellyfin:12.1ubu2604-ls50` (version-pinned)
- Config: `/DATA/AppData/jellyfin/config` (outside git)
- Media: `/mnt/media` (the 18TB disk) mounted into the container at `/media`
- Secret: `/opt/stacks/jellyfin/.env` (`OPENAI_API_KEY`, gitignored, mode 0600)
- Ports: bound to `192.168.1.70` + `127.0.0.1` only; DLNA on the LAN address.
  Remote access is via `tailscale serve` -> `tcp/8096` -> `127.0.0.1:8096`.
- Firewall: `docker-published-firewall.service` drops non-LAN traffic to all
  published Docker UI ports (8096/8920 included) in `DOCKER-USER`.

### Commands

```bash
cd /opt/stacks/jellyfin
sudo docker compose config
sudo docker compose ps
sudo docker compose logs -f --tail=100
sudo docker compose pull && sudo docker compose up -d    # update
sudo docker compose down                                 # stop/remove
```

First run: open `http://192.168.1.70:8096` (LAN) or the tailnet URL and complete
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
├── Books/        # Jellyfin "Books" library
├── Datasets/     # datasets / general storage (not a Jellyfin library)
├── Images/       # Jellyfin "Photos" library
├── Movies/       # Jellyfin "Movies" library
├── Music/        # Jellyfin "Music" library
├── TV Shows/     # Jellyfin "Shows" library
└── Videos/       # Jellyfin "Home Videos" library
```

Files must be readable/writable by UID/GID `1000` (the disk is `chown`ed to
`1000:1000`, matching Jellyfin's `PUID`/`PGID`).

## Storage — 18TB media disk

The Seagate One Touch Hub USB disk (`/dev/sda`, 16.4 TiB, ext4) is mounted at
`/mnt/media` by UUID from `/etc/fstab`:

```
UUID=215cb891-4aea-4712-9346-05a226bc0fc6 /mnt/media ext4 defaults,nofail,noatime,nosuid,nodev,x-systemd.device-timeout=10 0 2
```

- `nofail` + `x-systemd.device-timeout=10`: boot does not hang or fail if the
  USB disk is unplugged.
- The disk is owned by `1000:1000` so Jellyfin (and the `giacolees` user) can
  read and write media.
- The previous `devmon` automount path
  (`/media/devmon/sda1-usb-Seagate_One_Touc`) is unstable and is **no longer
  used**. `devmon@devmon.service` is currently disabled; if you ever re-enable
  it, add `--ignore-device /dev/sda1` (or set a filesystem label and
  `--ignore-label`) to `/etc/conf.d/devmon` to avoid it grabbing the disk.

Check the mount and free space:

```bash
findmnt /mnt/media
df -h /mnt/media
sudo findmnt --verify --verbose   # validate fstab
```

## Downloads / *arr stack

The "click to request, and it lands in the right folder" flow:

    Jellyseerr -> Prowlarr -> Sonarr / Radarr -> qBittorrent (via Gluetun VPN)
                                              \-> SABnzbd (Usenet)
    Bazarr -> subtitles

- Stack: `/opt/stacks/downloads/compose.yaml`
- Secrets: `/opt/stacks/downloads/.env` (VPN credentials, gitignored)
- State: `/opt/stacks/downloads/config/<app>` (gitignored)
- All apps mount the 18TB disk at `/data` (same filesystem as the libraries, so
  Sonarr/Radarr **hardlink** imports instead of copying).

| App         | Purpose                   | Host port | Tailnet URL |
|-------------|---------------------------|-----------|-------------|
| Jellyseerr  | Request UI ("click")      | 5055      | `http://<node>.<tailnet>.ts.net:5055` |
| Prowlarr    | Indexer manager           | 9696      | `...:9696` |
| Sonarr      | TV automation             | 8989      | `...:8989` |
| Radarr      | Movies automation         | 7878      | `...:7878` |
| Bazarr      | Subtitles                 | 6767      | `...:6767` |
| qBittorrent | Torrents (behind Gluetun) | 8080      | `...:8080` |
| SABnzbd     | Usenet                    | 8081      | `...:8081` |

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
3. **qBittorrent** (after the VPN is up): set the admin password.
4. **Sonarr**: add root folder `/data/TV Shows`; add qBittorrent (host `gluetun`,
   port `8080`) as a download client.
5. **Radarr**: root folder `/data/Movies`; add qBittorrent.
6. **SABnzbd**: add your Usenet server; add it as a download client in Sonarr/Radarr.
7. **Bazarr**: add languages + subtitle providers; connect Sonarr/Radarr.
8. **Jellyseerr**: sign in with Jellyfin, connect Sonarr/Radarr.
9. In Jellyfin, scan libraries so imported media appears.

## Nextcloud

Personal cloud (files, photos, calendar) at `/opt/stacks/nextcloud`.

- URL (LAN): http://192.168.1.70:8082
- URL (tailnet): http://homelees-1.lungfish-pike.ts.net:8082
- App/config: `/home/nextcloud/config` (SSD)
- Database (MariaDB): `/home/nextcloud/db` (SSD)
- Redis: `/home/nextcloud/redis` (SSD)
- User data: `/mnt/media/Nextcloud/data` (18TB disk)
- Secrets: `/opt/stacks/nextcloud/.env` (gitignored, mode 0600)
- Admin user: `admin` (password in `.env`)

```bash
cd /opt/stacks/nextcloud
sudo docker compose config
sudo docker compose ps
sudo docker compose logs -f --tail=100
sudo docker compose pull && sudo docker compose up -d   # update
```

`occ` (Nextcloud CLI):
```bash
sudo docker exec -u www-data nextcloud php occ status
sudo docker exec -u www-data nextcloud php occ config:system:get trusted_domains
```

## Immich

Self-hosted photo & video library with a mobile app for background upload
(the Google Photos replacement). At `/opt/stacks/immich`.

- URL (LAN): http://192.168.1.70:2283
- URL (tailnet): http://homelees-1.lungfish-pike.ts.net:2283
- Images: `ghcr.io/immich-app/immich-server:v3.2.2` and
  `immich-machine-learning:v3.2.2`, plus Valkey 9 and Immich's PostgreSQL 14
  (VectorChord + pgvecto.rs)
- Library (uploads, thumbnails, encoded video): `/mnt/media/Immich` (18TB disk)
- Database + ML model cache: named volumes `immich_pgdata` and
  `immich_model-cache` (SSD — Docker data-root `/home/docker`)
- Secrets: `/opt/stacks/immich/.env` (gitignored, mode 0600) — holds `DB_PASSWORD`
- Transcoding uses the AMD Radeon Vega iGPU via VAAPI (`/dev/dri`); machine
  learning runs on CPU (AMD integrated GPUs are not supported for ML)
- Port 2283 is bound to the LAN address + loopback, filtered by
  `docker-published-firewall.service`; remote access is via `tailscale serve`

```bash
cd /opt/stacks/immich
sudo docker compose config
sudo docker compose ps
sudo docker compose logs -f --tail=100
sudo docker compose pull && sudo docker compose up -d   # update
```

### First run

1. Open the URL and create the first user — this account becomes the admin.
2. Install the Immich mobile app and point it at the URL, then enable backup.

The Immich version is pinned in `.env` via `IMMICH_VERSION`. Bump it
deliberately and read the release notes before pulling, since Immich requires
occasional database migrations.

## Backups

Back up `/opt/stacks` (git remote or archive) and each app's data directory
(e.g. `/DATA/<app>`). Komodo keeps its state in the `komodo` Mongo volume and
writes scheduled backups under `/home/giacolees/komodo/backups`; send both to
encrypted storage. The retired Dockge state at `/opt/dockge/data` (admin hash +
JWT secret) can be backed up on encrypted storage or deleted.
