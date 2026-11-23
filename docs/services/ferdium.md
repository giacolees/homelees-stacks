# Ferdium Server

[← back to overview](../../README.md)

## Ferdium Server

Self-hosted sync and recipe server for Ferdium desktop clients (`ferdium/ferdium-server`).
At `/opt/stacks/ferdium`.

- URL (LAN): http://192.168.1.70:3333
- URL (HTTPS, LAN + NetBird): `https://ferdium.homelees.party`
- User Dashboard: `/user/login` (`/user/account`, `/user/data`, `/user/export`, `/import`, `/new`)
- Image: `ferdium/ferdium-server:2.0.14` (pinned in `.env`)
- Database (SQLite), app key & JWT PEM keys: `/home/ferdium/data` (SSD)
- Recipes store & archives: `/home/ferdium/recipes` (SSD)
- Port 3333 is bound to LAN + loopback and filtered by
  `docker-published-firewall.service`; remote access is via NetBird -> Caddy (`https://<name>.homelees.party`)

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
   - `https://ferdium.homelees.party` (LAN + NetBird) or `http://192.168.1.70:3333` (LAN only).
3. Create your account (or sign in on additional devices to sync all services and workspaces).
4. Optional: once your personal account is created, you can set `IS_REGISTRATION_ENABLED=false` in `/opt/stacks/ferdium/.env` and run `sudo docker compose up -d` to disable new user sign-ups.
