# Beszel

[← back to overview](../../README.md)

## Beszel

Lightweight host + per-container monitoring (CPU, memory, disk, network) with
history and alerts. Hub + agent, at `/opt/stacks/beszel`.

- URL (LAN): http://192.168.1.70:8090
- URL (HTTPS, LAN + NetBird): `https://beszel.homelees.party`
- Images: `henrygd/beszel:0.20.0` + `henrygd/beszel-agent:0.20.0` (pinned in `.env`)
- Hub data: `/home/beszel/data` (SSD)
- Agent data: `/home/beszel/agent_data` (SSD)
- Admin: created from `BESZEL_ADMIN_EMAIL` / `BESZEL_ADMIN_PASSWORD` in `.env`
  on first start
- Agent: `network_mode: host` and the Docker socket mounted read-only
  (root-equivalent — keep the hub LAN-only); connects to the hub over WebSocket
- Port 8090 is bound to LAN + loopback and filtered by
  `docker-published-firewall.service`; remote access is via NetBird -> Caddy (`https://<name>.homelees.party`)

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
