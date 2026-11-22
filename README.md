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
├── downloads/                # *arr stack (Sonarr/Radarr) + Gluetun VPN
│   ├── compose.yaml
│   ├── .env                  # VPN credentials (gitignored)
│   └── config/               # per-app state (gitignored)
├── requests/                 # Seerr request UI (user-facing, own stack)
│   ├── compose.yaml
│   └── config/               # Seerr state (gitignored)
├── homepage/                 # dashboard (links to every app)
│   ├── compose.yaml
│   └── config/               # services.yaml, settings.yaml, widgets.yaml
├── nextcloud/                # files/photos/calendar
│   ├── compose.yaml
│   └── .env                  # DB/admin passwords (gitignored)
│   ├── compose.yaml
│   ├── .env                  # DB passwords (gitignored, mode 0600)
│   └── .env.example          # committed template with placeholders
│   ├── compose.yaml
│   ├── .env                  # version pin (gitignored, mode 0600)
│   └── .env.example          # committed template with placeholders
├── beszel/                   # host + per-container monitoring (hub + agent)
│   ├── compose.yaml
│   ├── .env                  # admin password + agent key/token (gitignored, 0600)
│   └── .env.example          # committed template with placeholders
├── ferdium/                  # Ferdium client sync & recipe server
│   ├── compose.yaml
│   ├── .env                  # runtime config (gitignored, mode 0600)
│   └── .env.example          # committed template with placeholders
├── navidrome/                # Subsonic/OpenSubsonic music server & web player
│   ├── compose.yaml
│   ├── .env                  # version pin & optional Last.fm keys (gitignored, 0600)
│   └── .env.example          # committed template with placeholders
├── octo-fiesta/              # Subsonic proxy that fills Navidrome gaps from Deezer
│   ├── compose.yaml
│   ├── .env                  # version pin & Deezer ARL (gitignored, 0600)
│   └── .env.example          # committed template with placeholders
└── <app>/                    # one directory per stack
    ├── compose.yaml          # canonical stack definition (preferred name)
    ├── .env                  # OPTIONAL, per-stack secrets — NEVER committed
    └── .env.example          # OPTIONAL, committed template with dummy values

/opt/stacks/komodo       # Komodo (build/deploy web UI) - in this repo since 2026-11-22
├── compose.yaml              # Komodo Core + Periphery + MongoDB (name: komodo)
├── .env                      # Core/Periphery config + secrets (0600, gitignored)
└── .env.example              # committed template
/home/komodo/backups          # scheduled Komodo DB backups (SSD)

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
| `/opt/stacks/komodo` | giacolees:giacolees | 0755 | Komodo compose + config                  |
| `.../komodo/.env` | giacolees:giacolees | 0600 | Komodo secrets; root-only-ish            |
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
private keys, or Komodo's `.env` / Dockge's `data/`.** Commit only
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
- URL (tailnet): http://homelees.lungfish-pike.ts.net:3000
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
- URL (tailnet): `http://homelees.lungfish-pike.ts.net:9120`
- Stack: `/opt/stacks/komodo/compose.yaml` (Core + Periphery + Mongo)
- Config/secrets: `/opt/stacks/komodo/.env` (mode 0600). Self-registration is
  disabled (`KOMODO_DISABLE_USER_REGISTRATION=true`).
- Security: Periphery has the Docker socket and terminals enabled, so a Komodo
  admin login is equivalent to root on this host. Keep it LAN/VPN-only.
- Admin login: created on first launch; credentials in `.env`
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
cd /opt/stacks/komodo
sudo docker compose ps
sudo docker compose up -d
sudo docker compose logs -f --tail=100
# update: pull newer images and recreate
sudo docker compose pull
sudo docker compose up -d
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
| Beszel      | `http://<node>.<tailnet>.ts.net:8090` |
| Jellyfin    | `http://<node>.<tailnet>.ts.net:8096` |
| Homepage    | `http://<node>.<tailnet>.ts.net:3000` |
| Nextcloud   | `http://<node>.<tailnet>.ts.net:8082` |
| Seerr       | `http://<node>.<tailnet>.ts.net:5055` |
| Prowlarr    | `http://<node>.<tailnet>.ts.net:9696` |
| Sonarr      | `http://<node>.<tailnet>.ts.net:8989` |
| Radarr      | `http://<node>.<tailnet>.ts.net:7878` |
| Bazarr      | `http://<node>.<tailnet>.ts.net:6767` |
| qBittorrent | `http://<node>.<tailnet>.ts.net:8080` |
| SABnzbd     | `http://<node>.<tailnet>.ts.net:8081` |
| Ferdium     | `http://<node>.<tailnet>.ts.net:3333` |
| Navidrome   | `http://<node>.<tailnet>.ts.net:4533` |
| Octo-Fiesta | `http://<node>.<tailnet>.ts.net:5275` |

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
├── Books/        # Jellyfin "Books" library (flat PDFs/EPUBs)
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

| App         | Purpose                   | Host port | Tailnet URL |
|-------------|---------------------------|-----------|-------------|
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

## Requests / Seerr stack

The user-facing request portal ("click to request"), split out of `downloads`
so it is decoupled from the acquisition + VPN stack.

- Stack: `/opt/stacks/requests/compose.yaml`
- Image: `ghcr.io/seerr-team/seerr:v3.4.1` (unified Overseerr + Jellyseerr)
- State: `/opt/stacks/requests/config/jellyseerr` (gitignored)
- URL (LAN): http://192.168.1.70:5055
- URL (tailnet): `http://<node>.<tailnet>.ts.net:5055`
- External networks:
  - `media_net` -> Jellyfin (`http://jellyfin:8096`) for auth + library sync
  - `downloads_default` -> Sonarr/Radarr (`http://sonarr:8989`, `http://radarr:7878`)

## Nextcloud

Personal cloud (files, photos, calendar) at `/opt/stacks/nextcloud`.

- URL (LAN): http://192.168.1.70:8082
- URL (tailnet): http://homelees.lungfish-pike.ts.net:8082
- App/config: `/home/nextcloud/config` (SSD)
- Database (MariaDB): `/home/nextcloud/db` (SSD)
- Redis: `/home/nextcloud/redis` (SSD)
- User data: `/mnt/media/Nextcloud/data` (18TB disk)
- Secrets: `/opt/stacks/nextcloud/.env` (gitignored, mode 0600)
- Admin user: `admin` (password in `.env`)
- Image: built from `nextcloud/Dockerfile` (`nextcloud:stable-apache` plus
  ffmpeg, exiftool and ImageMagick extras that Memories needs), tagged
  `homelees/nextcloud:apache-memories`

```bash
cd /opt/stacks/nextcloud
sudo docker compose config
sudo docker compose ps
sudo docker compose logs -f --tail=100
# update: rebuild on a newer base image, then recreate
sudo docker compose build --pull && sudo docker compose up -d
```

### Photos (Memories)

[Memories](https://memories.gallery/) is the photo timeline and replaces the
need for a separate Immich stack. Apps installed: `memories` +
`previewgenerator`; previews tuned to 2048px / JPEG q60.

- URL: http://192.168.1.70:8082/apps/memories
- Timeline folder: set per user (default `/Photos`). After uploading files
  outside Nextcloud, index them:
  ```bash
  sudo docker exec -u www-data nextcloud php occ files:scan --all
  sudo docker exec -u www-data nextcloud php occ memories:index
  ```

`occ` (Nextcloud CLI):
```bash
sudo docker exec -u www-data nextcloud php occ status
sudo docker exec -u www-data nextcloud php occ config:system:get trusted_domains
```

## Beszel

Lightweight host + per-container monitoring (CPU, memory, disk, network) with
history and alerts. Hub + agent, at `/opt/stacks/beszel`.

- URL (LAN): http://192.168.1.70:8090
- URL (tailnet): `http://<node>.<tailnet>.ts.net:8090`
- Images: `henrygd/beszel:0.20.0` + `henrygd/beszel-agent:0.20.0` (pinned in `.env`)
- Hub data: `/home/beszel/data` (SSD)
- Agent data: `/home/beszel/agent_data` (SSD)
- Admin: created from `BESZEL_ADMIN_EMAIL` / `BESZEL_ADMIN_PASSWORD` in `.env`
  on first start
- Agent: `network_mode: host` and the Docker socket mounted read-only
  (root-equivalent — keep the hub LAN-only); connects to the hub over WebSocket
- Port 8090 is bound to LAN + loopback and filtered by
  `docker-published-firewall.service`; remote access is via `tailscale serve`

The hub lists every container with its CPU/memory (per-container history is in
`container_stats`). Homepage links to it from the Management group.

```bash
cd /opt/stacks/beszel
sudo docker compose config
sudo docker compose ps
sudo docker compose logs -f --tail=100
sudo docker compose pull && sudo docker compose up -d   # update
```

### Agent key/token

The agent authenticates with the hub's public key (`BESZEL_AGENT_KEY`) and a
per-system registration token (`BESZEL_AGENT_TOKEN`). To add another machine,
use **Add System** in the hub UI and paste the generated key/token into `.env`.
The hub's public key can also be derived from `/home/beszel/data/id_ed25519`
with `ssh-keygen -y -f /home/beszel/data/id_ed25519`.

## Ferdium Server

Self-hosted sync and recipe server for Ferdium desktop clients (`ferdium/ferdium-server`).
At `/opt/stacks/ferdium`.

- URL (LAN): http://192.168.1.70:3333
- URL (tailnet): `http://homelees.lungfish-pike.ts.net:3333`
- User Dashboard: `/user/login` (`/user/account`, `/user/data`, `/user/export`, `/import`, `/new`)
- Image: `ferdium/ferdium-server:2.0.14` (pinned in `.env`)
- Database (SQLite), app key & JWT PEM keys: `/home/ferdium/data` (SSD)
- Recipes store & archives: `/home/ferdium/recipes` (SSD)
- Port 3333 is bound to LAN + loopback and filtered by
  `docker-published-firewall.service`; remote access is via `tailscale serve`

```bash
cd /opt/stacks/ferdium
sudo docker compose config
sudo docker compose ps
sudo docker compose logs -f --tail=100
sudo docker compose pull && sudo docker compose up -d   # update
```

### Connecting a Ferdium Client

1. In the Ferdium desktop app, click the settings gear icon (or on the welcome screen, click **Change Server**).
2. Select **Custom Server** and enter:
   - `http://homelees.lungfish-pike.ts.net:3333` (works everywhere on your tailnet) or `http://192.168.1.70:3333` (LAN only).
3. Create your account (or sign in on additional devices to sync all services and workspaces).
4. Optional: once your personal account is created, you can set `IS_REGISTRATION_ENABLED=false` in `/opt/stacks/ferdium/.env` and run `sudo docker compose up -d` to disable new user sign-ups.

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
> (firewall + `tailscale serve`), landing-page row, Homepage entry, the
> `/home/octo` data directory and the `/opt/stacks/octo` stack were all removed.
> History is in git (`git log --all -- octo/`).

### Navidrome

- URL (LAN): http://192.168.1.70:4533
- URL (tailnet): `http://homelees.lungfish-pike.ts.net:4533`
- Image: `deluan/navidrome:0.64.2` (pinned in `.env`)
- App data, SQLite DB & transcode/image caches: `/home/navidrome/data` -> `/config` (SSD)
- Music library (read-only mount): `/home/navidrome/music` -> `/data:ro` (SSD)
- Port 4533 is bound to LAN + loopback and filtered by
  `docker-published-firewall.service`; remote access is via `tailscale serve`
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
- URL (tailnet): `http://homelees.lungfish-pike.ts.net:5275`
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
  `docker-published-firewall.service`; remote access is via `tailscale serve`
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

## Backups

Back up `/opt/stacks` (git remote or archive) and each app's data directory
(e.g. `/DATA/<app>`). Komodo keeps its state in the `komodo` Mongo volume and
writes scheduled backups under `/opt/stacks/komodobackups`; send both to
encrypted storage. The retired Dockge state at `/opt/dockge/data` (admin hash +
JWT secret) can be backed up on encrypted storage or deleted.

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

## Host hardening (2026-11-22)

Host-level configuration that is **not** a Docker stack. Backups of every
replaced file sit next to it with a `.bak-20261122` / `.debian-default` suffix.

- **SSH** — `/etc/ssh/sshd_config.d/10-hardening.conf`: `PermitRootLogin no`,
  `X11Forwarding no`, `MaxAuthTries 4`, `AllowUsers giacolees`. Key auth is set
  up (`~/.ssh/authorized_keys`, key "mac → homelees"). `PasswordAuthentication`
  is still **on** until key login from the LAN is confirmed; then set it to `no`
  in that file and `sudo systemctl reload ssh`. Note: Tailscale SSH
  (`tailscale up --ssh`) authenticates by tailnet identity and bypasses sshd.
- **Disabled services** — Samba (`smbd`, `nmbd`, `samba-ad-dc`), CUPS
  (`cups`, `cups-browsed`), avahi. Re-enable with `systemctl enable --now <unit>`.
- **Host firewall** — `/etc/nftables.conf`, `nftables.service` (enabled).
  INPUT only, policy drop, own table `inet homelees`. Allows: loopback,
  `tailscale0`, Docker bridges, ICMP, UDP 41641 (Tailscale direct), DHCPv6, and
  TCP 22/80/9090 from `192.168.1.0/24`. Everything else (incl. IPv6 from the
  internet) is dropped and rate-limit logged (`journalctl -k | grep homelees-drop`).
  The file **must never contain `flush ruleset`** and the unit's `ExecStop` is
  overridden (`/etc/systemd/system/nftables.service.d/homelees.conf`) so stopping
  it never wipes Docker/Tailscale rules. Safe apply pattern:
  ```bash
  sudo nft -c -f /etc/nftables.conf                       # validate
  sudo systemd-run --unit=nft-rollback --on-active=180 /usr/sbin/nft delete table inet homelees
  sudo nft -f /etc/nftables.conf                          # apply
  sudo systemctl stop nft-rollback.timer                  # keep, once verified
  ```
- **Docker daemon** — `/etc/docker/daemon.json`: `live-restore: true` (dockerd
  restarts/upgrades no longer stop containers), `log-driver: local` with
  10 MB × 3 rotation (applies to containers as they are recreated).
- **Updates** — `unattended-upgrades` installs Debian security/point updates
  daily, never reboots (`/etc/apt/apt.conf.d/52homelees-unattended`). Docker,
  containerd, Tailscale and NetBird are excluded and upgraded by hand.
  `tailscale` is additionally `apt-mark hold` until it can be upgraded from a
  non-Tailscale session (its restart drops Tailscale SSH sessions).
- **Pending reboot** — kernel 6.1.0-56 is installed; the running kernel stays
  6.1.0-53 until the next (planned) reboot.

## Backups (restic)

Nightly encrypted, deduplicated backups by `/usr/local/sbin/homelees-backup.sh`
(`homelees-backup.timer`, 03:30) with a weekly integrity check
(`homelees-backup-check.timer`, Sun 06:00, reads 5% of the data).

| Repo | Location | Contents |
| :--- | :--- | :--- |
| Local | `/mnt/media/Backups/restic` (18 TB HDD) | `system`, `nextcloud`, `music` |
| Offsite | Google Drive (Google One) via rclone remote `gdrive:` → `homelees-restic/` | `system`, `nextcloud` |

The offsite repo is used automatically once `rclone config` has created a
remote named `gdrive` (type `drive`, scope `drive.file`) for **root**:
`sudo rclone config`. Until then the script backs up locally and warns.

**Password**: `/root/.config/restic/password` (0600). Both repos use it.
**Keep a copy in your password manager — without it the backups are unreadable.**

What is backed up (tags):
- `system` — `/opt/stacks` (incl. `.env` secrets, only ever stored encrypted),
  `/opt/stacks/komodo`, app state in `/home/{beszel,ferdium,octo-fiesta}`,
  `/home/nextcloud/config`, `/home/navidrome/data`, Jellyfin config
  (`/DATA/AppData/jellyfin`), `/etc`, `/usr/local/sbin`, `/var/www/html`, and
  `/home/backup/dumps`: consistent dumps of MariaDB (Nextcloud), Postgres
  (wellness), MongoDB (Komodo) and an online-API copy of every SQLite DB.
- `nextcloud` — `/mnt/media/Nextcloud/data` (previews/caches excluded).
- `music` — `/home/navidrome/music` (local repo only).
- Not backed up: Movies/TV/Downloads (re-downloadable), transcodes, caches.
  Excludes: `/etc/homelees/backup-excludes.txt`.

Retention: 7 daily, 4 weekly, 6 monthly per tag. Status of the last run:
`/var/lib/homelees-status/backup.json`; logs: `journalctl -u homelees-backup`.

```bash
# Common commands (as root)
export RESTIC_PASSWORD_FILE=/root/.config/restic/password RESTIC_CACHE_DIR=/home/backup/restic-cache
R=/mnt/media/Backups/restic          # or rclone:gdrive:homelees-restic
sudo -E restic -r $R snapshots
sudo systemctl start homelees-backup.service       # run now
# Restore one app into a scratch dir, then compare / copy back:
sudo -E restic -r $R restore latest --tag system --include /home/ferdium --target /home/backup/restore-test
# Databases: restore the dump from /home/backup/dumps, e.g.
#   zcat nextcloud-mariadb.sql.gz | docker exec -i nextcloud-db sh -c 'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD"'
#   zcat wellness-postgres.sql.gz | docker exec -i wellness-db sh -c 'psql -U "$POSTGRES_USER" postgres'
#   docker exec -i komodo-mongo-1 sh -c 'mongorestore --archive --gzip --drop -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin' < komodo-mongo.archive.gz
```

## Monitoring, alerts & updates (2026-11-22)

All alerts go to one Telegram chat through `/usr/local/sbin/tg-notify "msg"`
(credentials in `/etc/homelees/telegram.env`, 0600: `TG_TOKEN=…`,
`TG_CHAT_ID=…`). Until that file exists, alerts are only logged:
`journalctl -t tg-notify`.

| Source | What | Schedule |
| :--- | :--- | :--- |
| `homelees-healthcheck.timer` → `/usr/local/sbin/homelees-healthcheck` | `/mnt/media` mounted, disk usage (85%, 90% for media//tmp), kernel storage I/O errors, ext4 error counters, failed units, unhealthy/stopped/restart-looping containers, backup age/status, low memory, VPN up. Alerts only on **change** (new problem / resolved). State: `/var/lib/homelees-status/health.json` | every 10 min |
| `smartmontools` (`/etc/smartd.conf`) → `smartd-notify` | NVMe SMART + temperature, self-tests (short Sun 03:00, long 1st 04:00). The Seagate One Touch Hub USB enclosure does **not** pass SMART through, so the HDD is covered by the kernel-error/ext4 checks above instead. | continuous |
| `homelees-backup` | failure, or offsite not configured | nightly |
| Diun (`/opt/stacks/diun`) | new version tags for every pinned image | daily 09:00 |
| `docker-cleanup.timer` | prunes images unused for >7 days + build cache >2 GB | monthly |

`vm.swappiness=10` (`/etc/sysctl.d/90-homelees.conf`). The 1 GB swap fills
with cold pages of long-running daemons; that is harmless — watch
`/proc/pressure/memory`, not swap usage.

### Updating an image

Every image is pinned to an explicit version (or digest for gluetun).
Diun reports new tags. To upgrade:

```bash
cd /opt/stacks/<stack>
# edit the tag in compose.yaml (or the *_VERSION var in .env)
sudo docker compose pull && sudo docker compose up -d && sudo docker compose ps
# also bump the matching entry in /opt/stacks/diun/images.yml, then:
cd /opt/stacks && git commit -am "<stack>: bump <image> to <tag>"
```
Rollback = restore the previous tag and `up -d` again (old images are kept 7 days).

## Telegram bot (`/opt/stacks/telegram-bot`)

[@homelees_bot](https://t.me/homelees_bot), **read-only**, answers only the
admin chat (`TG_CHAT_ID`; others are ignored and logged).

- Commands: `/status`, `/containers`, `/disk`, `/backup`, `/health`, `/smart`,
  `/vpn`, `/updates`, `/help`.
- Push alerts come from the host, not the bot: `tg-notify` (health check on
  change, backup failures, SMART, any failed homelees systemd unit via
  `notify-failure@.service` `OnFailure=` drop-ins), Diun (image updates), and
  `homelees-digest.timer` (daily report at 09:00).
- Built locally (`Dockerfile`, `app/bot.py`; base `python:3.13.17-slim-bookworm`,
  `python-telegram-bot==22.8`), image `homelees/telegram-bot:1.0.0`.
- Docker access only through `tecnativa/docker-socket-proxy:0.3.0`
  (`CONTAINERS=1`, everything else denied) on an `internal` network. Host data
  comes from `/var/lib/homelees-status/*.json` (read-only mount), written by
  `homelees-healthcheck` and `homelees-backup`. Container is read-only, non-root,
  all capabilities dropped, 128 MB limit. No published ports (long polling).
- Secrets: `.env` here, `diun/.env`, and `/etc/homelees/telegram.env` (all 0600).
  **Rotate the token**: `/revoke` in @BotFather, then update the three files and
  `sudo docker compose up -d` in `telegram-bot/` and `diun/`.

```bash
cd /opt/stacks/telegram-bot
sudo docker compose build --pull && sudo docker compose up -d   # after editing app/bot.py
sudo docker compose logs -f bot
```
