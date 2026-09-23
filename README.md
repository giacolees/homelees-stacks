# /opt/stacks — Docker Compose stacks (primary CLI)

This directory holds self-hosted app stacks for **homelees** (Debian 12).
**`docker compose` is the primary management interface.** Dockge is an optional
web UI that reads/writes the same stacks.

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
└── <app>/                    # one directory per stack
    ├── compose.yaml          # canonical stack definition (preferred name)
    ├── .env                  # OPTIONAL, per-stack secrets — NEVER committed
    └── .env.example          # OPTIONAL, committed template with dummy values

/opt/dockge/
├── compose.yaml              # Dockge's own stack (LAN-bound UI on :5001)
└── data/                     # Dockge state + admin password hash + JWT
                              # root:root, mode 0700 — never commit/copy around
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
| `/opt/dockge`            | giacolees:giacolees | 0755 | compose file editable                    |
| `/opt/dockge/data`       | root:root      | 0700  | secrets; root-only                       |
| `/var/run/docker.sock`   | root:docker    | 0660  | root-equivalent access                   |

`/opt/stacks` uses a setgid bit and a **default ACL** so files created by root
(for example when Dockge creates a stack from its UI) remain editable by the
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

Rollback Dockge itself:

Dockge's compose file lives at `/opt/dockge/compose.yaml` (outside this git
repo). Keep a copy or track it in your own config backup, then:

```bash
cd /opt/dockge
sudo docker compose config
sudo docker compose up -d
```

## Git & credentials

`/opt/stacks` is a git repo. `.gitignore` excludes `.env`, key material, and
common state directories. **Never commit credentials, tokens, `.env` files,
private keys, or Dockge's `data/` directory.** Commit only compose files and
`.env.example` templates with placeholder values.

```bash
cd /opt/stacks
git status
git add <app>/compose.yaml
git commit -m "add <app> stack"
```

---

## Homepage (dashboard)

One page listing every app — no need to remember IP:port. Config is YAML under
`/opt/stacks/homepage/config` (tracked in git; no secrets).

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

## Dockge (optional web UI)

- URL: **http://192.168.1.70:5001**
- Stack: `/opt/dockge/compose.yaml` (official `louislam/dockge:1` image)
- Dockge manages the same `/opt/stacks` directory, so CLI and UI stay in sync.

### Access control

The UI is **not exposed to the public Internet**:

1. The published port is bound to the LAN address only:
   `192.168.1.70:5001:5001` (not `0.0.0.0`, not IPv6). Verify:
   ```bash
   sudo ss -tlnp | grep 5001      # should show 192.168.1.70:5001
   ```
2. Docker published ports **bypass the host INPUT chain**, so a `DOCKER-USER`
   rule drops tcp/5001 from any source outside `192.168.1.0/24`. This also
   protects against router port-forwarding. All published Docker UI ports are
   managed together by `docker-published-firewall.service`:
   ```bash
   sudo iptables -S DOCKER-USER
   systemctl status docker-published-firewall.service
   ```
   To allow a VPN subnet or add a new UI port, edit `LAN`/`PORTS` in
   `/usr/local/sbin/docker-published-firewall.sh` and run
   `sudo systemctl restart docker-published-firewall.service`.

Dockge mounts `/var/run/docker.sock` (root-equivalent) and therefore must be
treated as an admin tool. Anyone who can reach :5001 and log in can control
Docker. Keep it on the LAN/VPN.

### Dockge lifecycle

```bash
cd /opt/dockge
sudo docker compose config
sudo docker compose up -d
sudo docker compose logs -f --tail=100
sudo docker compose pull && sudo docker compose up -d   # update
```

First login: open the URL and create the admin account (stored in
`/opt/dockge/data`, root-only).

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
in Debian; Docker Compose management is done with the CLI and Dockge.

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

Cockpit and Dockge stay bound to the LAN **and loopback only**. `tailscale
serve` forwards tailnet traffic to loopback, so nothing new is exposed on the
LAN or the public Internet:

| Service     | Tailnet URL |
|-------------|-------------|
| Cockpit     | `https://<node>.<tailnet>.ts.net:9090` (self-signed cert warning) |
| Dockge      | `http://<node>.<tailnet>.ts.net:5001` |
| Jellyfin    | `http://<node>.<tailnet>.ts.net:8096` |
| Homepage    | `http://<node>.<tailnet>.ts.net:3000` |
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
dropped (chain `COCKPIT-FW`). Docker-published ports (Dockge) are **not**
reachable directly over Tailscale — only through `tailscale serve`.

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

## Backups

Back up `/opt/stacks` (git remote or archive) and each app's data directory
(e.g. `/DATA/<app>`). Dockge's `/opt/dockge/data` contains its admin hash and
JWT secret; back it up only to encrypted storage.
