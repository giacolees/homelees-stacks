# Books (Calibre-Web-Automated + Shelfmark)

[← back to overview](../../README.md)

## Books: Shelfmark + Calibre-Web-Automated (e-reader)

Flow:

    Shelfmark (downloads stack, in Gluetun's netns -> VPN egress)
      searches Anna's Archive / LibGen / Z-Library, downloads EPUB/MOBI/AZW3/FB2
      -> /mnt/media/Books/ingest
    Calibre-Web-Automated (books stack) imports: metadata, covers, convert -> EPUB
      -> /mnt/media/Books/library  -> OPDS + KOReader sync -> Xteink X4 Pro (CrossPoint)

- **CWA** `crocodilestick/calibre-web-automated:v4.0.8` (`books/.env`),
  http://192.168.1.70:8083, https://books.homelees.party (SSO; `/opds` and
  `/kosync` bypass Authelia and use CWA's own basic auth). State
  `/home/books/cwa` (app.db = user accounts), library `/mnt/media/Books/library`,
  ingest `/mnt/media/Books/ingest` (files deleted after import).
- **Shelfmark** `ghcr.io/calibrain/shelfmark:v1.7.0` (standard image, built-in
  Chromium bypasser), defined in `downloads/compose.yaml` with
  `network_mode: service:gluetun` like qBittorrent; its port 8084 is published on
  the `gluetun` service and listed in `FIREWALL_INPUT_PORTS`. All its traffic
  (search, DDoS-Guard solve, downloads) leaves via the VPN; if Gluetun is down it
  has no network (kill switch). FlareSolverr is **not** used: DDoS-Guard cookies
  are IP-bound and FlareSolverr's solve didn't clear Anna's Archive anyway.
  http://192.168.1.70:8084, https://shelfmark.homelees.party (SSO).
  State `/home/books/shelfmark`. Logins = CWA accounts (`AUTH_METHOD=cwa`, CWA's
  `/config` mounted read-only at `/auth`); restart shelfmark after changing a
  CWA password. Shelfmark opens `app.db`/`metadata.db` with SQLite `immutable=1`,
  so CWA runs with `NETWORK_SHARE_MODE=true` (no WAL) and both DBs were switched
  to `journal_mode=DELETE`; otherwise new users/passwords stay invisible in
  `app.db-wal`. Formats `epub,mobi,azw3,fb2,pdf` (PDF added 2026-11-23 for coursebooks and excluded from CWA auto-convert, so it is imported as PDF; read those on a tablet/PC, not the X4 Pro's
  4.3" screen). Search mode **Direct** (UI setting, 2026-11-23): searches Anna's
  Archive by title instead of via Hardcover metadata, so books Hardcover lacks
  (method books, coursebooks) still show up. Languages `en,it`. Mirrors (they move often — edit in
  `downloads/compose.yaml`): AA `annas-archive.gl`, LibGen `libgen.li`/`libgen.bz`,
  Z-Library `z-library.sk`. Optional `AA_DONATOR_KEY` in `downloads/.env`.
- Recreating `gluetun` (e.g. changing its ports) also recreates qBittorrent and
  Shelfmark: `cd /opt/stacks/downloads && sudo docker compose up -d`.

E-reader (Xteink X4 Pro, CrossPoint firmware), on the home Wi-Fi:
- OPDS: File Transfer -> OPDS Browser -> add `http://192.168.1.70:8083/opds`
  with a CWA username/password.
- KOReader sync: server `http://192.168.1.70:8083/kosync` (enable in CWA admin
  settings first), same CWA credentials.

```bash
cd /opt/stacks/books && sudo docker compose logs -f          # CWA
cd /opt/stacks/downloads && sudo docker compose logs -f shelfmark
```
