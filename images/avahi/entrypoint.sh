#!/bin/sh
# Starts avahi-daemon with the services in /etc/avahi/services, and keeps an
# NFS service there for each path in the host's export table, when
# /var/lib/nfs is mounted.
set -eu

etab=/var/lib/nfs/etab
services=/etc/avahi/services

etab_sum() {
	if [ -r "$etab" ]; then
		cksum <"$etab"
	fi
}

# A restart keeps the container's files, including the old daemon's pid.
rm -f /run/avahi-daemon/pid

last=$(etab_sum)
nfs-services.sh "$etab" "$services"

# Exports change at runtime, through exportfs or ZFS's sharenfs, so the
# services follow the table rather than a list in configuration.
(
	while sleep 10; do
		sum=$(etab_sum)
		# A failed update is tried again on the next pass.
		if [ "$sum" != "$last" ] &&
			nfs-services.sh "$etab" "$services" &&
			avahi-daemon --reload; then
			last=$sum
		fi
	done
) &

# The default limit of three processes counts every process on the host
# with the avahi user's UID, which other containers can share.
exec avahi-daemon --no-rlimits "$@"
