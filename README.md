# /opt/stacks — Docker Compose stacks (primary CLI)

This directory holds self-hosted app stacks for **homelees** (Debian 12).
**`docker compose` is the primary management interface.** Dockge is an optional
web UI that reads/writes the same stacks.

> This machine already runs a Jellyfin container that was previously managed by
> CasaOS. Its compose project directory was removed, so it is now an orphaned
> container and is **not** managed from here. Do not recreate/remove it from
> this repo.

---

## Directory layout

```
/opt/stacks/
├── README.md                 # this file
├── .gitignore                # keeps credentials/state out of git
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
   protects against router port-forwarding. Managed by
   `dockge-firewall.service`:
   ```bash
   sudo iptables -S DOCKER-USER
   systemctl status dockge-firewall.service
   ```
   To also allow a VPN subnet, edit `LAN` in
   `/usr/local/sbin/dockge-firewall.sh` and run
   `sudo systemctl restart dockge-firewall.service`.

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

## Backups

Back up `/opt/stacks` (git remote or archive) and each app's data directory
(e.g. `/DATA/<app>`). Dockge's `/opt/dockge/data` contains its admin hash and
JWT secret; back it up only to encrypted storage.
