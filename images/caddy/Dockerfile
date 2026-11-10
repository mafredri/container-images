FROM caddy:2.11.9-builder AS builder

# renovate: datasource=go depName=github.com/caddy-dns/he
ARG CADDY_DNS_HE_VERSION=v1.2.2

# The builder image sets CADDY_VERSION, so xcaddy builds the same Caddy
# release as the runtime image below.
RUN xcaddy build --with github.com/caddy-dns/he@${CADDY_DNS_HE_VERSION}

FROM caddy:2.11.9

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
