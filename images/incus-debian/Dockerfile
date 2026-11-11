FROM debian:13.7-slim

# Docker and containerd migrate their stores forward only, so their
# versions are pinned: raise them together, never lower them.
ARG DOCKER_VERSION=5:29.9.3-1~debian.13~trixie
ARG CONTAINERD_VERSION=2.4.2-3~debian.13~trixie
ARG BUILDX_VERSION=0.38.1-1~debian.13~trixie
ARG COMPOSE_VERSION=5.7.0-1~debian.13~trixie

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Debian's packages are not pinned: like apk packages elsewhere in this
# repository, pins would churn on every point release.
# hadolint ignore=DL3008
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		dbus \
		iproute2 \
		systemd \
		systemd-sysv \
	&& install -m 0755 -d /etc/apt/keyrings \
	&& curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
	&& printf '%s\n' 'Types: deb' 'URIs: https://download.docker.com/linux/debian' 'Suites: trixie' \
		'Components: stable' 'Signed-By: /etc/apt/keyrings/docker.asc' >/etc/apt/sources.list.d/docker.sources \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		"docker-ce=${DOCKER_VERSION}" \
		"docker-ce-cli=${DOCKER_VERSION}" \
		"containerd.io=${CONTAINERD_VERSION}" \
		"docker-buildx-plugin=${BUILDX_VERSION}" \
		"docker-compose-plugin=${COMPOSE_VERSION}" \
	&& rm -rf /var/lib/apt/lists/*

# Incus runs the image as a system container in its OCI mode: it does DHCP
# for the container itself and manages /etc/hosts, /etc/hostname and
# /etc/resolv.conf from the host, so nothing in the image may manage the
# network or name resolution. The machine ID comes from the instance (a
# systemd.credential.system.machine_id key) or is generated at boot.
RUN systemctl mask \
		systemd-networkd.service \
		systemd-networkd.socket \
		systemd-resolved.service \
		systemd-timesyncd.service \
		getty@.service \
		console-getty.service \
	&& systemctl enable docker.service containerd.service \
	&& : >/etc/machine-id \
	&& rm -f /var/lib/dbus/machine-id

# systemd as PID 1. Incus starts the container with the entrypoint as init
# only when it is exactly /sbin/init.
ENTRYPOINT ["/sbin/init"]
