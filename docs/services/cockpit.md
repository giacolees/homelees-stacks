# Cockpit

[← back to overview](../../README.md)

## Cockpit (host management UI)

- URL: **https://192.168.1.70:9090** (self-signed certificate — accept the
  browser warning)
- Installed from Debian as **system packages** (not a container): `cockpit`,
  `cockpit-system`, `cockpit-networkmanager`, `cockpit-packagekit`,
  `cockpit-storaged`.
- Login uses system PAM accounts (use the `giacolees` account and its password).

### Access control

1. `cockpit.socket` is bound to the LAN address only via
   `/etc/systemd/system/cockpit.socket.d/listen.conf`
   (`ListenStream=192.168.1.70:9090`, packaged default cleared). Verify:
   ```bash
   systemctl show cockpit.socket -p Listen
   sudo ss -tlnp | grep 9090      # should show 192.168.1.70:9090 only
   ```
2. Because Cockpit is a host service, it is filtered by the normal `INPUT`
   chain. `cockpit-firewall.service` drops tcp/9090 from any source outside
   `192.168.1.0/24` (loopback excepted), which also blocks router
   port-forwarding:
   ```bash
   sudo iptables -S INPUT
   systemctl status cockpit-firewall.service
   ```
   To also allow a VPN subnet, edit `LAN` in
   `/usr/local/sbin/cockpit-firewall.sh` and run
   `sudo systemctl restart cockpit-firewall.service`.

### Lifecycle

```bash
sudo systemctl status cockpit.socket
sudo systemctl restart cockpit.socket
sudo apt-get update && sudo apt-get install --only-upgrade cockpit
```

Cockpit generates a self-signed certificate (`CN=homelees`, 1-year validity).
For a trusted certificate, put Cockpit behind the existing Apache reverse proxy
or install a real certificate. Note: Cockpit does **not** ship a Docker module
in Debian; Docker Compose management is done with the CLI and Komodo.
