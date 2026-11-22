#!/bin/sh
set -eu

PORT="${1:-}"
if [ -z "$PORT" ]; then
  echo "No port provided" >&2
  exit 1
fi

# In case multiple ports are passed comma-separated, take the first one
PORT="${PORT%%,*}"

COOKIE_FILE="/tmp/qb_cookies.txt"
rm -f "$COOKIE_FILE"

# Wait up to 60s for qBittorrent WebUI to come up on 127.0.0.1:8080
i=0
while [ "$i" -lt 30 ]; do
  if wget -q -O /dev/null --save-cookies "$COOKIE_FILE" --keep-session-cookies \
    --post-data "username=${QBITTORRENT_USER}&password=${QBITTORRENT_PASSWORD}" \
    "http://127.0.0.1:8080/api/v2/auth/login" 2>/dev/null; then
    break
  fi
  i=$((i + 1))
  sleep 2
done

if [ ! -s "$COOKIE_FILE" ]; then
  echo "Failed to authenticate to qBittorrent WebUI" >&2
  exit 1
fi

wget -q -O /dev/null --load-cookies "$COOKIE_FILE" \
  --post-data "json={\"listen_port\":${PORT},\"upnp\":false,\"random_port\":false}" \
  "http://127.0.0.1:8080/api/v2/app/setPreferences"

rm -f "$COOKIE_FILE"
echo "Updated qBittorrent listen_port to ${PORT}"
