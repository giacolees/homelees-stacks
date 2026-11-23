# Remote access & SSO

[← back to overview](../README.md)

## NetBird (remote access VPN)

NetBird (`netbird.service`, official apt repo, upgraded by hand) is the only
remote path; nothing is port-forwarded on the router. The server is
`homelees.netbird.cloud` / `10.200.82.85` (network range `10.200.0.0/16`, set
up with `--disable-dns`, no client/server routes). Tailscale was removed on
2026-11-23 (see [history](history.md)).

- **Over NetBird only HTTPS is open**: use `https://<service>.homelees.party`
  (Caddy + Authelia, below). SSH (`ssh giacolees@homelees.netbird.cloud`) also
  works, because the host firewall accepts everything on `wt0`, but
  Docker-published `:port`s are LAN-only (`docker-published-firewall`).
- **Direct port exceptions**: `netbird-remote-access.sh` runs a
  `netbird-forward@<port>` socat unit (NetBird IP → `192.168.1.70:<port>`,
  never loopback) only for ports in `host/netbird-direct.txt` (empty by
  default; add one only for a native client that can't use the HTTPS name).
- **Add a device**: install the NetBird client, sign in with the same account
  (or a setup key from app.netbird.io → Setup Keys), then open
  `https://home.homelees.party`.
- **Health**: `homelees-healthcheck` alerts on Telegram if NetBird loses its
  management connection; the bot's `/vpn` shows `netbird status`.

```bash
sudo netbird status          # -d for per-peer detail
sudo /usr/local/sbin/netbird-remote-access.sh   # after editing netbird-direct.txt
sudo apt-get update && sudo apt-get install --only-upgrade netbird   # drops NetBird SSH sessions briefly
```

On the LAN every service also answers on `http://192.168.1.70:<port>`
(ports in `host/ports.txt`) and Cockpit on `https://192.168.1.70:9090`.

## SSO & HTTPS (`/opt/stacks/sso`) — https://\<service\>.homelees.party

- **NetBird = HTTPS only (2026-11-23)**: over NetBird only `:443` (Caddy) is
  open, so `http://homelees.netbird.cloud:<port>` no longer bypasses Authelia.
  `netbird-remote-access.sh` forwards only ports listed in
  `host/netbird-direct.txt` (empty; add one only for a native client that can't
  use the HTTPS name). The landing page links to the HTTPS names when opened
  over NetBird. The LAN keeps the direct `:port` URLs.
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
