# Monitoring, alerts & backups

[← back to overview](../README.md)

## Backups

Back up `/opt/stacks` (git remote or archive) and each app's data directory
(e.g. `/DATA/<app>`). Komodo keeps its state in the `komodo` Mongo volume and
writes scheduled backups under `/opt/stacks/komodobackups`; send both to
encrypted storage. The retired Dockge state at `/opt/dockge/data` (admin hash +
JWT secret) can be backed up on encrypted storage or deleted.

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
  `/home/nextcloud/config`, `/home/navidrome/data`, `/home/books` (CWA +
  Shelfmark state), Jellyfin config
  (`/DATA/AppData/jellyfin`), `/etc`, `/usr/local/sbin`, `/var/www/html`, and
  `/home/backup/dumps`: consistent dumps of MariaDB (Nextcloud),
  MongoDB (Komodo) and an online-API copy of every SQLite DB.
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
| `homelees-image-updates.timer` → `/usr/local/sbin/homelees-image-updates` | newer version of every pinned image (watch list `host/image-watch.yml`; only tag lists are fetched, no manifest pulls). **One** Telegram message, only for versions not reported before: `image (stack): current → newest`, `⚠️ MAJOR` on a major-version jump. Result `/var/lib/homelees-status/images.json` → 09:00 digest line and bot `/updates`. Re-send the full list: `sudo homelees-image-updates --notify-all` | daily 08:45 |
| `docker-cleanup.timer` | prunes images unused for >7 days + build cache >2 GB | monthly |

`vm.swappiness=10` (`/etc/sysctl.d/90-homelees.conf`). The 1 GB swap fills
with cold pages of long-running daemons; that is harmless — watch
`/proc/pressure/memory`, not swap usage.

### Updating an image

Every image is pinned to an explicit version (or digest for gluetun).
`homelees-image-updates` reports new versions (Telegram / bot `/updates`). The
Diun container was retired on 2026-11-23: with `watch_repo` it alerted on every
*old* tag of each repo (≈2000 messages/day) and hit Docker Hub rate limits;
its old `images.yml` lives on as `host/image-watch.yml`, the watch list (`name` = the pinned tag, `include_tags`
= regex of the release line). To upgrade:

```bash
cd /opt/stacks/<stack>
# edit the tag in compose.yaml (or the *_VERSION var in .env)
sudo docker compose pull && sudo docker compose up -d && sudo docker compose ps
# also bump the matching entry in /opt/stacks/host/image-watch.yml, then:
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
  `notify-failure@.service` `OnFailure=` drop-ins), `homelees-image-updates`
  (new Docker image versions, 08:45), and
  `homelees-digest.timer` (daily report at 09:00).
- Built locally (`Dockerfile`, `app/bot.py`; base `python:3.13.17-slim-bookworm`,
  `python-telegram-bot==22.8`), image `homelees/telegram-bot:1.0.0`.
- Docker access only through `tecnativa/docker-socket-proxy:0.3.0`
  (`CONTAINERS=1`, everything else denied) on an `internal` network. Host data
  comes from `/var/lib/homelees-status/*.json` (read-only mount), written by
  `homelees-healthcheck` and `homelees-backup`. Container is read-only, non-root,
  all capabilities dropped, 128 MB limit. No published ports (long polling).
- Secrets: `.env` here and `/etc/homelees/telegram.env` (both 0600). **Rotate the token**: `/revoke` in
  @BotFather, then update both files and `sudo docker compose up -d` here.

```bash
cd /opt/stacks/telegram-bot
sudo docker compose build --pull && sudo docker compose up -d   # after editing app/bot.py
sudo docker compose logs -f bot
```
