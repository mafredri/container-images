# avahi

avahi-daemon for a host's mDNS, run with host networking. It advertises the
service files in `/etc/avahi/services`, and an NFS service for each path the
host exports.

## NFS

Mount the host's `/var/lib/nfs` read-only. exportfs keeps the export table
there, including exports from `/etc/exports.d` and ZFS's `sharenfs`. The
image writes one `_nfs._tcp` service per exported path, named
`<host-name> <path>`, and updates them within 10 seconds of a change. Without
the mount it advertises no NFS services.

## Example

```yaml
services:
  avahi:
    image: ghcr.io/mafredri/avahi:main
    network_mode: host
    restart: unless-stopped
    volumes:
      - ./avahi-daemon.conf:/etc/avahi/avahi-daemon.conf:ro
      - ./smb.service:/etc/avahi/services/smb.service:ro
      - /var/lib/nfs:/var/lib/nfs:ro
```

A replacement `avahi-daemon.conf` must keep `enable-dbus=no`; the container
has no D-Bus.
