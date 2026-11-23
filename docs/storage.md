# Storage

[← back to overview](../README.md)

## Storage — 18TB media disk

The Seagate One Touch Hub USB disk (`/dev/sda`, 16.4 TiB, ext4) is mounted at
`/mnt/media` by UUID from `/etc/fstab`:

```
UUID=215cb891-4aea-4712-9346-05a226bc0fc6 /mnt/media ext4 defaults,nofail,noatime,nosuid,nodev,x-systemd.device-timeout=10 0 2
```

- `nofail` + `x-systemd.device-timeout=10`: boot does not hang or fail if the
  USB disk is unplugged.
- The disk is owned by `1000:1000` so Jellyfin (and the `giacolees` user) can
  read and write media.
- The previous `devmon` automount path
  (`/media/devmon/sda1-usb-Seagate_One_Touc`) is unstable and is **no longer
  used**. `devmon@devmon.service` is currently disabled; if you ever re-enable
  it, add `--ignore-device /dev/sda1` (or set a filesystem label and
  `--ignore-label`) to `/etc/conf.d/devmon` to avoid it grabbing the disk.

Check the mount and free space:

```bash
findmnt /mnt/media
df -h /mnt/media
sudo findmnt --verify --verbose   # validate fstab
```
