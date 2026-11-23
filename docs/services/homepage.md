# Homepage

[← back to overview](../../README.md)

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
