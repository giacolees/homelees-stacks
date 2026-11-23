# Remote access & SSO

[← back to overview](../README.md)

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
| Calibre-Web (CWA) | `http://<node>.<tailnet>.ts.net:8083` |
| Shelfmark   | `http://<node>.<tailnet>.ts.net:8084` |

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

## SSO & HTTPS (`/opt/stacks/sso`) — https://\<service\>.homelees.party

- **NetBird = HTTPS only (2026-11-23)**: over NetBird only `:443` (Caddy) is
  open, so `http://homelees.netbird.cloud:<port>` no longer bypasses Authelia.
  `netbird-remote-access.sh` forwards only ports listed in
  `host/netbird-direct.txt` (empty; add one only for a native client that can't
  use the HTTPS name). The landing page links to the HTTPS names when opened
  over NetBird. LAN and Tailscale keep the direct `:port` URLs.
- **DNS**: Cloudflare zone `homelees.party`, one record `*.homelees.party A
  10.200.82.85` (the server's **NetBird** IP; DNS-only, not proxied). Names work
  on every NetBird device; nothing is reachable from the internet. Cloudflare API
  token (Zone DNS edit, this zone only): `/etc/homelees/cloudflare.env` and
  `sso/.env` (0600).
- **Caddy** (`caddy/Caddyfile`, custom build with `caddy-dns/cloudflare`,
  host network, binds `192.168.1.70`, `10.200.82.85`, `127.0.0.1` :443;
  `net.ipv4.ip_nonlocal_bind=1` so it starts before NetBird at boot). Wildcard
  Let's Encrypt cert via DNS-01, auto-renewed, stored in `/home/sso/caddy/data`.
  Apache keeps :80. Docker pulls go through `mirror.gcr.io` (daemon.json) to
  avoid Docker Hub rate limits.
- **Authelia** 4.39 (`authelia/configuration.yml`, loopback :9091) at
  https://auth.homelees.party — policy `two_factor`: password + passkey, or a
  **passkey alone** (Touch ID / Face ID counts as both factors via
  `experimental_enable_passkey_uv_two_factors`).
  User file `/home/sso/authelia/users.yml`; secrets `/home/sso/authelia/secrets`;
  initial password `/root/.config/homelees/authelia-password`. No mail server:
  one-time codes (passkey registration) land in
  `/home/sso/authelia/data/notification.txt`.

| Host | Service | Auth |
| :--- | :--- | :--- |
| `home` | Homepage | SSO (2FA) |
| `sonarr` `radarr` `prowlarr` `bazarr` `sab` `torrent` | *arr / SABnzbd / qBittorrent | SSO (`/api` bypassed → app API key) |
| `shelfmark` | Shelfmark | SSO + Shelfmark login (CWA accounts) |
| `books` | Calibre-Web-Automated | SSO; `/opds`, `/kosync` bypassed (CWA basic auth, e-readers) |
| `cockpit` | Cockpit | SSO + Cockpit login |
| `music` | Navidrome | SSO: trusts `Remote-User` from Caddy only (`ND_REVERSEPROXYWHITELIST=172.25.0.1/32`); `/rest`, `/share`, `/ping` bypassed (Subsonic apps keep their own auth) |
| `jellyfin` `cloud` `subsonic` `requests` `komodo` `beszel` `ferdium` | apps with their own login / native clients | app login (OIDC next) |

Old `http://<ip>:<port>` URLs keep working. Hostname allow-lists updated for
the new names: Nextcloud `trusted_domains`, Homepage `HOMEPAGE_ALLOWED_HOSTS`,
SABnzbd `host_whitelist`, Cockpit `/etc/cockpit/cockpit.conf` `Origins`.

### SSO buttons (OIDC, Authelia as provider)

Authelia is an OpenID Connect provider (`identity_providers.oidc` in
`sso/authelia/configuration.yml`; keys/digests in `/home/sso/authelia/secrets`,
loaded via `X_AUTHELIA_CONFIG_FILTERS=template`; plaintext client secrets in
`/root/.config/homelees/oidc/<client>.secret`). Claims policy `homelees` puts
`preferred_username`, `name`, `email`, `groups` in the ID token.

| App | Setup | Account mapping |
| :--- | :--- | :--- |
| Nextcloud | app `user_oidc`, provider "Authelia" (`occ user_oidc:provider`), PKCE, `allow_local_remote_servers=true` (auth host is a private IP). **Auto-redirect** to Authelia (`user_oidc allow_multiple_user_backends=0`, 2026-11-23); local/admin password login: `https://cloud.homelees.party/login?direct=1` | `preferred_username` → existing user (soft auto-provision) |
| Komodo | `KOMODO_OIDC_*` in `komodo/.env`, `KOMODO_HOST=https://komodo.homelees.party`, `KOMODO_OIDC_USE_FULL_EMAIL=true`. Sign-up only via OIDC (`KOMODO_DISABLE_LOCAL_USER_REGISTRATION=true`, `KOMODO_DISABLE_OIDC_USER_REGISTRATION=false`, `KOMODO_ENABLE_NEW_USERS=true`; Authelia only knows our users). `KOMODO_OIDC_AUTO_REDIRECT=true` (on since 2026-11-23); `auth.homelees.party` pinned via `extra_hosts` (discovery runs only at startup). Break-glass: set auto-redirect `false` in `.env`, `up -d core`, log in as local `admin` | OIDC user `<authelia email>` = admin + super admin (promoted 2026-11-23) |
| Beszel | PocketBase `users` collection → OAuth2 provider "Authelia" (`oidc`, client `beszel`); `APP_URL=https://beszel.homelees.party`. Password login kept as fallback | by email (user email set to the Authelia email) |
| Jellyfin, Seerr, Ferdium, Octo-Fiesta | no OIDC (Seerr v3.4 has none; Seerr logs in with Jellyfin accounts; Ferdium/Octo-Fiesta are API servers for native clients) | own login |
