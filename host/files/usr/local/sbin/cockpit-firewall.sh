#!/bin/sh
# Restrict Cockpit's web UI (tcp/9090) to the trusted LAN and loopback. Cockpit is a host service, so it is filtered by the normal INPUT
# chain. The socket is bound to 192.168.1.70 and 127.0.0.1 only; this rule is
# defence-in-depth so a router port-forward cannot reach it from off-LAN, while
# still allowing loopback (Caddy -> https://cockpit.<domain>).
set -eu

CHAIN="COCKPIT-FW"
PORT="9090"
LAN="192.168.1.0/24"
IPT="/usr/sbin/iptables"

add_rule() {
    "$IPT" -N "$CHAIN" 2>/dev/null || true
    "$IPT" -F "$CHAIN"
    "$IPT" -A "$CHAIN" -i lo -j RETURN
    "$IPT" -A "$CHAIN" -s "$LAN" -j RETURN
    "$IPT" -A "$CHAIN" -j DROP
    "$IPT" -C INPUT -p tcp --dport "$PORT" -j "$CHAIN" 2>/dev/null || \
        "$IPT" -I INPUT 1 -p tcp --dport "$PORT" -j "$CHAIN"
}

del_rule() {
    "$IPT" -D INPUT -p tcp --dport "$PORT" -j "$CHAIN" 2>/dev/null || true
    "$IPT" -F "$CHAIN" 2>/dev/null || true
    "$IPT" -X "$CHAIN" 2>/dev/null || true
}

case "${1:-}" in
    start) add_rule ;;
    stop)  del_rule ;;
    *) echo "usage: $0 {start|stop}" >&2; exit 2 ;;
esac
