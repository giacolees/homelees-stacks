# Host security

[← back to overview](../README.md)

## Host hardening (2026-11-22)

Host-level configuration that is **not** a Docker stack. Backups of every
replaced file sit next to it with a `.bak-20261122` / `.debian-default` suffix.

- **SSH** — `/etc/ssh/sshd_config.d/10-hardening.conf`: `PermitRootLogin no`,
  `X11Forwarding no`, `MaxAuthTries 4`, `AllowUsers giacolees`, `PasswordAuthentication no`. Key auth is set
  up (`~/.ssh/authorized_keys`, key "mac → homelees"). `PasswordAuthentication`
  is still **on** until key login from the LAN is confirmed; then set it to `no`
  in that file and `sudo systemctl reload ssh`. Note: Tailscale SSH
  (`tailscale up --ssh`) authenticates by tailnet identity and bypasses sshd.
- **Disabled services** — Samba (`smbd`, `nmbd`, `samba-ad-dc`), CUPS
  (`cups`, `cups-browsed`), avahi. Re-enable with `systemctl enable --now <unit>`.
- **Host firewall** — `/etc/nftables.conf`, `nftables.service` (enabled).
  INPUT only, policy drop, own table `inet homelees`. Allows: loopback,
  `tailscale0`, Docker bridges, ICMP, UDP 41641 (Tailscale direct), DHCPv6, and
  TCP 22/80/9090 from `192.168.1.0/24`. Everything else (incl. IPv6 from the
  internet) is dropped and rate-limit logged (`journalctl -k | grep homelees-drop`).
  The file **must never contain `flush ruleset`** and the unit's `ExecStop` is
  overridden (`/etc/systemd/system/nftables.service.d/homelees.conf`) so stopping
  it never wipes Docker/Tailscale rules. Safe apply pattern:
  ```bash
  sudo nft -c -f /etc/nftables.conf                       # validate
  sudo systemd-run --unit=nft-rollback --on-active=180 /usr/sbin/nft delete table inet homelees
  sudo nft -f /etc/nftables.conf                          # apply
  sudo systemctl stop nft-rollback.timer                  # keep, once verified
  ```
- **Docker daemon** — `/etc/docker/daemon.json`: `live-restore: true` (dockerd
  restarts/upgrades no longer stop containers), `log-driver: local` with
  10 MB × 3 rotation (applies to containers as they are recreated).
- **Updates** — `unattended-upgrades` installs Debian security/point updates
  daily, never reboots (`/etc/apt/apt.conf.d/52homelees-unattended`). Docker,
  containerd, Tailscale and NetBird are excluded and upgraded by hand.
  `tailscale` is additionally `apt-mark hold` until it can be upgraded from a
  non-Tailscale session (its restart drops Tailscale SSH sessions).
- **Pending reboot** — kernel 6.1.0-56 is installed; the running kernel stays
  6.1.0-53 until the next (planned) reboot.
