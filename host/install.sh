#!/bin/sh
# Rebuild helper: install ./files/* onto a fresh host (shows a diff first).
# Secrets are NOT in git: restore /etc/homelees/telegram.env,
# /root/.config/restic/password, /root/.config/rclone and the stacks' .env
# files from the restic backup (see docs/monitoring.md "Backups").
set -eu
cd "$(dirname "$0")/files"
find . -type f | sed 's#^\.##' | sort | while read -r f; do
    if ! sudo cmp -s ".$f" "$f" 2>/dev/null; then
        echo "=== $f"; sudo diff -u "$f" ".$f" 2>/dev/null | head -20 || true
    fi
done
printf 'Install the files above? [y/N] '; read -r a; [ "$a" = y ] || exit 0
find . -type f | sed 's#^\.##' | while read -r f; do
    mode=644; case "$f" in /usr/local/sbin/*) mode=755 ;; /etc/ssh/*|/etc/apt/*) mode=644 ;; esac
    sudo install -D -m $mode -o root -g root ".$f" "$f"
done
sudo systemctl daemon-reload
echo "Installed. Enable: nftables homelees-backup.timer homelees-backup-check.timer homelees-healthcheck.timer homelees-digest.timer docker-cleanup.timer docker-published-firewall tailscale-serve smartmontools unattended-upgrades"
