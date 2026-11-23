# Nextcloud

[← back to overview](../../README.md)

## Nextcloud

Personal cloud (files, photos, calendar) at `/opt/stacks/nextcloud`.

- URL (LAN): http://192.168.1.70:8082
- URL (HTTPS, LAN + NetBird): `https://cloud.homelees.party`
- App/config: `/home/nextcloud/config` (SSD)
- Database (MariaDB): `/home/nextcloud/db` (SSD)
- Redis: `/home/nextcloud/redis` (SSD)
- User data: `/mnt/media/Nextcloud/data` (18TB disk)
- Secrets: `/opt/stacks/nextcloud/.env` (gitignored, mode 0600)
- Admin user: `admin` (password in `.env`)
- Image: built from `nextcloud/Dockerfile` (`nextcloud:stable-apache` plus
  ffmpeg, exiftool and ImageMagick extras that Memories needs), tagged
  `homelees/nextcloud:apache-memories`

```bash
cd /opt/stacks/nextcloud
sudo docker compose config
sudo docker compose ps
sudo docker compose logs -f --tail=100
# update: rebuild on a newer base image, then recreate
sudo docker compose build --pull && sudo docker compose up -d
```

### Photos (Memories)

[Memories](https://memories.gallery/) is the photo timeline and replaces the
need for a separate Immich stack. Apps installed: `memories` +
`previewgenerator`; previews tuned to 2048px / JPEG q60.

- URL: http://192.168.1.70:8082/apps/memories
- Timeline folder: set per user (default `/Photos`). After uploading files
  outside Nextcloud, index them:
  ```bash
  sudo docker exec -u www-data nextcloud php occ files:scan --all
  sudo docker exec -u www-data nextcloud php occ memories:index
  ```

`occ` (Nextcloud CLI):
```bash
sudo docker exec -u www-data nextcloud php occ status
sudo docker exec -u www-data nextcloud php occ config:system:get trusted_domains
```
