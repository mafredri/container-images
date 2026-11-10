#!/usr/bin/env bash
# Usage: test.sh IMAGE
#
# Checks that the image's Caddy includes the Hurricane Electric DNS provider
# and accepts a site that uses it for the ACME DNS challenge.
set -euo pipefail

image=$1
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

if ! docker run --rm "$image" caddy list-modules | grep -qx 'dns.providers.he'; then
	echo "FAIL: caddy lacks the dns.providers.he module" >&2
	exit 1
fi

cat >"$dir/Caddyfile" <<'CADDYFILE'
example.com {
	tls {
		dns he test-key
	}
	respond "ok"
}
CADDYFILE

if ! docker run --rm -v "$dir/Caddyfile:/etc/caddy/Caddyfile:ro" "$image" \
	caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; then
	echo "FAIL: caddy rejects a site using dns he" >&2
	exit 1
fi

echo "caddy: OK"
