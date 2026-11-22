#!/bin/sh
# Sync netbird-forward@<port> instances with /opt/stacks/host/ports.txt
# (all kinds: docker + host). Replaces tailscale-remote-access.sh after migration.
set -eu
PORTS_FILE=/opt/stacks/host/ports.txt
want=$(awk '!/^[[:space:]]*#/ && NF {print $1}' "$PORTS_FILE" | sort -n)
have=$(systemctl list-units --all --plain --no-legend 'netbird-forward@*.service' | sed -n 's/^netbird-forward@\([0-9]*\)\.service.*/\1/p' | sort -n)
for p in $want; do systemctl enable --now "netbird-forward@$p.service" >/dev/null 2>&1; done
for p in $have; do echo "$want" | grep -qx "$p" || { systemctl disable --now "netbird-forward@$p.service" >/dev/null 2>&1; echo "removed $p"; }; done
systemctl enable netbird-forward.target >/dev/null 2>&1
NB=$(ip -4 -o addr show wt0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
echo "NetBird IP: ${NB:-<none>}"
for p in $want; do printf '%s:%s ' "$p" "$(systemctl is-active netbird-forward@$p.service)"; done; echo
