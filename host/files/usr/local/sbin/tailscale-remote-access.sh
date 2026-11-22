#!/bin/sh
# Manually (re)apply the `tailscale serve` config for all web UIs.
set -eu

TS="$(command -v tailscale)"
# Ports come from /opt/stacks/host/ports.txt (all ports); edit THAT file.
PORTS_FILE=/opt/stacks/host/ports.txt
FALLBACK_PORTS="3000 3100 3333 4533 5055 5275 6767 7878 8080 8081 8082 8090 8096 8989 9090 9120 9696"
if [ -r "$PORTS_FILE" ]; then
    PORTS="$(awk '!/^[[:space:]]*#/ && NF {print $1}' "$PORTS_FILE" | tr '\n' ' ')"
else
    echo "warning: $PORTS_FILE unreadable, using fallback list" >&2
    PORTS="$FALLBACK_PORTS"
fi
[ -n "$PORTS" ] || PORTS="$FALLBACK_PORTS"

state="$("$TS" status --json 2>/dev/null | grep -o '"BackendState"[^,]*' | head -1 | sed 's/.*"BackendState":[ ]*"\([^"]*\)"/\1/')"
if [ "${state:-}" != "Running" ]; then
    echo "Tailscale backend state is '${state:-unknown}', not 'Running'." >&2
    echo "Log in first with:  sudo tailscale up --ssh --accept-dns=false" >&2
    exit 1
fi

for p in $PORTS; do
    "$TS" serve --bg --tcp="$p" "tcp://192.168.1.70:$p"   # LAN IP; loopback is reserved for Caddy
done

echo
echo "=== tailscale serve status ==="
"$TS" serve status
