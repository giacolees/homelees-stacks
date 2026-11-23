# Operations runbook

[← back to overview](../README.md)

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
├── books/                    # Calibre-Web-Automated: ebook library, OPDS, KOReader sync
│   ├── compose.yaml          # (Shelfmark downloader lives in downloads/, behind Gluetun)
│   ├── .env                  # version pin, optional Hardcover token (gitignored, 0600)
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

**GitHub mirror (private): `giacolees/homelees-stacks`** (since 2026-11-23).
Push with `git push` (remote `origin` = `git@github-homelees-stacks:giacolees/homelees-stacks.git`).
Auth is a **deploy key** scoped to that repo only: `~/.ssh/github_homelees_stacks`
(+ `Host github-homelees-stacks` in `~/.ssh/config`); revoke it in the repo's
Settings → Deploy keys. A **pre-commit hook** (`.git/hooks/pre-commit`, not
versioned) refuses `.env`/key/`users.yml` files and runs gitleaks (offline,
pinned container) on staged changes; full-history scan:
`sudo docker run --rm --network none -v /opt/stacks:/repo:ro zricethezav/gitleaks:v8.21.2 git /repo --redact`.
Keep the repo private: it maps IPs, domain, tailnet and firewall rules.

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

## Host config in git (`/opt/stacks/host`)

- `ports.txt` — **single source of truth** for web-UI ports. Both
  `/usr/local/sbin/docker-published-firewall.sh` (DOCKER-USER, `docker` kind)
  and `/usr/local/sbin/tailscale-remote-access.sh` (all kinds) read it. To add or
  remove a port: edit `ports.txt`, then
  `sudo systemctl restart docker-published-firewall.service && sudo /usr/local/sbin/tailscale-remote-access.sh`.
- `files.txt` + `files/` — snapshot of every host config file we manage
  (sshd drop-in, nftables, daemon.json, smartd, apt/unattended, sysctl, systemd
  units/timers, `/usr/local/sbin` scripts, landing page). After changing any of
  them run `host/sync-from-system.sh`, review `git diff`, commit. It refuses
  secret-looking paths and aborts if a token/private key slips in.
- `install.sh` — rebuild helper for a fresh Debian host: shows a diff, then
  installs `files/`. Secrets come from the restic backup, not git.
