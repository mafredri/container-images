#!/usr/bin/env bash
# Usage: test.sh IMAGE
#
# Starts the image with a fake /var/lib/nfs/etab and checks that:
#   - each exported path gets one NFS service, and
#   - the services are updated after etab changes.
set -euo pipefail

image=$1
name=avahi-test-$$
nfs=$(mktemp -d)
trap 'docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$nfs"' EXIT

retry() {
	local tries=30
	until "$@"; do
		tries=$((tries - 1))
		if [ "$tries" -eq 0 ]; then
			docker logs "$name" >&2 || true
			echo "FAIL: $*" >&2
			return 1
		fi
		sleep 1
	done
}

established() {
	docker logs "$name" 2>&1 | grep -qF "Service \"avahi-test $1\" (/services/$2) successfully established."
}

services() {
	[ "$(docker exec "$name" sh -c 'cd /etc/avahi/services && echo nfs-*.service')" = "$1" ]
}

# etab has one line per path and client, so a path can repeat. exportfs
# writes spaces in paths as \040.
printf '%s\n' \
	'/data/media	10.0.0.0/24(rw)' \
	'/data/media	10.0.1.0/24(ro)' \
	'/srv/a\040b	*(ro)' >"$nfs/etab"
docker run -d --name "$name" --hostname avahi-test -v "$nfs:/var/lib/nfs:ro" "$image" >/dev/null

retry established /data/media nfs-data-media.service
retry established "/srv/a b" nfs-srv-a-b.service
services "nfs-data-media.service nfs-srv-a-b.service"
docker exec "$name" avahi-daemon --check

printf '%s\n' '/data/games	*(rw)' >"$nfs/etab"
retry established /data/games nfs-data-games.service
retry services nfs-data-games.service

echo "avahi: OK"
