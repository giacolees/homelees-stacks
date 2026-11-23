# Requests (Seerr)

[← back to overview](../../README.md)

## Requests / Seerr stack

The user-facing request portal ("click to request"), split out of `downloads`
so it is decoupled from the acquisition + VPN stack.

- Stack: `/opt/stacks/requests/compose.yaml`
- Image: `ghcr.io/seerr-team/seerr:v3.4.1` (unified Overseerr + Jellyseerr)
- State: `/opt/stacks/requests/config/jellyseerr` (gitignored)
- URL (LAN): http://192.168.1.70:5055
- URL (HTTPS, LAN + NetBird): `https://requests.homelees.party`
- External networks:
  - `media_net` -> Jellyfin (`http://jellyfin:8096`) for auth + library sync
  - `downloads_default` -> Sonarr/Radarr (`http://sonarr:8989`, `http://radarr:7878`)
