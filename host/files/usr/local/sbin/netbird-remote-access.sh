#!/bin/sh
# Sync netbird-forward@<port> instances. Only ports listed in BOTH
# /opt/stacks/host/ports.txt and /opt/stacks/host/netbird-direct.txt are
# forwarded on the NetBird IP; everything else is reached over NetBird only via
# https://<service>.homelees.party (Caddy + Authelia), so SSO can't be bypassed.
set -eu
PORTS_FILE=/opt/stacks/host/ports.txt
DIRECT_FILE=/opt/stacks/host/netbird-direct.txt
all=$(awk '!/^[[:space:]]*#/ && NF {print $1}' "$PORTS_FILE" | sort -n)
allowed=$( [ -r "$DIRECT_FILE" ] && awk '!/^[[:space:]]*#/ && NF {print $1}' "$DIRECT_FILE" | sort -n || true)
want=$(for p in $all; do echo "$allowed" | grep -qx "$p" && echo "$p"; done; true)
have=$(systemctl list-units --all --plain --no-legend 'netbird-forward@*.service' | sed -n 's/^netbird-forward@\([0-9]*\)\.service.*/\1/p' | sort -n)
for p in $want; do systemctl enable --now "netbird-forward@$p.service" >/dev/null 2>&1; done
for p in $have; do echo "$want" | grep -qx "$p" || { systemctl disable --now "netbird-forward@$p.service" >/dev/null 2>&1; systemctl reset-failed "netbird-forward@$p.service" 2>/dev/null || true; echo "removed $p"; }; done
systemctl enable netbird-forward.target >/dev/null 2>&1
NB=$(ip -4 -o addr show wt0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
echo "NetBird IP: ${NB:-<none>}  direct ports: ${want:-none} (use https://*.homelees.party)"
