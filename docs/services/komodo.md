# Komodo

[← back to overview](../../README.md)

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
`project_name`.

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
