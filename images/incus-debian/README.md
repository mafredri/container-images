# incus-debian

Debian 13 with systemd and Docker, for Incus system containers launched
from an OCI registry:

```sh
incus remote add ghcr https://ghcr.io --protocol=oci --public
incus launch ghcr:mafredri/incus-debian:main example -c security.nesting=true
```

Incus starts an OCI image's entrypoint as the container's init only when it
is exactly `/sbin/init`, so systemd runs as PID 1. In its OCI mode Incus
runs the container's DHCP client and writes `/etc/hosts`, `/etc/hostname`
and `/etc/resolv.conf` itself, so the image masks systemd-networkd,
systemd-resolved and systemd-timesyncd. The machine ID is empty, so each
boot generates one unless the instance passes a
`systemd.credential.system.machine_id`.

Docker runs inside the container, which needs `security.nesting=true`.
Docker CE and containerd are pinned in the Dockerfile; they migrate their
data forward only, so raise the versions together and never lower them.
