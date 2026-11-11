#!/usr/bin/env bash
# Usage: test.sh IMAGE
#
# systemd cannot boot as PID 1 under Docker in CI, so this checks what Incus
# relies on to boot the image as a system container:
#   - the entrypoint is /sbin/init, and it is systemd,
#   - the machine ID is empty and there is no /etc/hostname,
#   - nothing in the image manages the network or name resolution,
#   - Docker and containerd are installed and enabled.
set -euo pipefail

image=$1

entrypoint=$(docker image inspect --format '{{json .Config.Entrypoint}}' "$image")
if [ "$entrypoint" != '["/sbin/init"]' ]; then
	echo "FAIL: entrypoint is $entrypoint, not [\"/sbin/init\"]" >&2
	exit 1
fi

docker run --rm --entrypoint /bin/bash "$image" -euo pipefail -c '
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(readlink -f /sbin/init)" = /usr/lib/systemd/systemd ] || fail "/sbin/init is not systemd"
[ ! -s /etc/machine-id ] || fail "/etc/machine-id is not empty"
[ ! -e /etc/hostname ] || fail "/etc/hostname exists"
for unit in systemd-networkd.service systemd-resolved.service systemd-timesyncd.service; do
	[ "$(readlink /etc/systemd/system/$unit)" = /dev/null ] || fail "$unit is not masked"
done
for unit in docker.service containerd.service; do
	[ -e /etc/systemd/system/multi-user.target.wants/$unit ] || fail "$unit is not enabled"
done
command -v dockerd >/dev/null && command -v containerd >/dev/null || fail "Docker or containerd is missing"
'

echo "incus-debian: OK"
