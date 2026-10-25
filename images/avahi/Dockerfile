FROM alpine:3.24.3

# The image's own services would advertise SSH. D-Bus is not running in the
# container, and avahi-daemon exits at start while enable-dbus is on.
RUN apk add --no-cache \
	avahi \
	tini \
	&& rm -f /etc/avahi/services/* \
	&& sed -i 's/^#*enable-dbus=.*/enable-dbus=no/' /etc/avahi/avahi-daemon.conf \
	&& grep -qx 'enable-dbus=no' /etc/avahi/avahi-daemon.conf

COPY --chmod=755 entrypoint.sh nfs-services.sh /usr/local/bin/

HEALTHCHECK CMD ["avahi-daemon", "--check"]

ENTRYPOINT ["/sbin/tini", "--", "entrypoint.sh"]
