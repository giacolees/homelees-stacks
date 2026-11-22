#!/bin/sh
# Drop forwarded traffic to Docker-published TCP ports from outside the LAN.
# Docker published ports bypass the INPUT chain; DOCKER-USER is the supported
# hook. Off-LAN access is via `tailscale serve` (loopback), which does not
# traverse this chain. Add new UI ports to PORTS and restart the service.
set -eu

CHAIN="DOCKER-USER"
LAN="192.168.1.0/24"
# Ports come from /opt/stacks/host/ports.txt (docker-published ports); edit THAT file.
PORTS_FILE=/opt/stacks/host/ports.txt
FALLBACK_PORTS="3000 3100 3333 4533 5055 5275 6767 7878 8080 8081 8082 8090 8096 8989 9120 9696"
if [ -r "$PORTS_FILE" ]; then
    PORTS="$(awk '!/^[[:space:]]*#/ && $2=="docker" {print $1}' "$PORTS_FILE" | tr '\n' ' ')"
else
    echo "warning: $PORTS_FILE unreadable, using fallback list" >&2
    PORTS="$FALLBACK_PORTS"
fi
[ -n "$PORTS" ] || PORTS="$FALLBACK_PORTS"
IPT="/usr/sbin/iptables"

add_rule() {
    for p in $PORTS; do
        "$IPT" -C "$CHAIN" -p tcp --dport "$p" ! -s "$LAN" -j DROP 2>/dev/null || \
            "$IPT" -I "$CHAIN" 1 -p tcp --dport "$p" ! -s "$LAN" -j DROP
    done
}

# Remove DROP rules for ports no longer in PORTS, so retiring a service
# actually closes its hole instead of leaving a stale rule behind.
prune_rule() {
    "$IPT" -S "$CHAIN" 2>/dev/null | while read -r rule; do
        case "$rule" in
            *"-A $CHAIN"*"--dport "*"-j DROP"*) ;;
            *) continue ;;
        esac
        case "$rule" in
            *"! -s $LAN"*"-p tcp"*"-j DROP") ;;
            *) continue ;;
        esac
        port=$(printf '%s' "$rule" | sed -n 's/.*--dport \([0-9][0-9]*\).*/\1/p')
        [ -n "$port" ] || continue
        keep=0
        for p in $PORTS; do
            if [ "$p" = "$port" ]; then keep=1; break; fi
        done
        [ "$keep" = 1 ] && continue
        "$IPT" -D "$CHAIN" $(printf '%s' "$rule" | sed "s/^-A $CHAIN //") && \
            echo "pruned stale rule for port $port"
    done
}

del_rule() {
    for p in $PORTS; do
        "$IPT" -D "$CHAIN" -p tcp --dport "$p" ! -s "$LAN" -j DROP 2>/dev/null || true
    done
}

case "${1:-}" in
    start) prune_rule; add_rule ;;
    stop)  del_rule ;;
    *) echo "usage: $0 {start|stop}" >&2; exit 2 ;;
esac
