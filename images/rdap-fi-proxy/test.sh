#!/usr/bin/env bash
# Usage: test.sh IMAGE
#
# Checks that the server starts and /healthz responds. Domain lookups call
# Traficom's servers, so the Go tests cover them instead.
set -euo pipefail

image=$1
name=rdap-fi-proxy-test-$$
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$name" -p 127.0.0.1::8080 "$image" >/dev/null
port=$(docker port "$name" 8080/tcp | head -n1 | cut -d: -f2)

tries=30
until curl -fsS -o /dev/null "http://127.0.0.1:$port/healthz"; do
	tries=$((tries - 1))
	if [ "$tries" -eq 0 ]; then
		docker logs "$name" >&2 || true
		echo "FAIL: /healthz did not respond" >&2
		exit 1
	fi
	sleep 1
done

echo "rdap-fi-proxy: OK"
