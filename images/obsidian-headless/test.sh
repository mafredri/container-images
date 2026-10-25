#!/usr/bin/env bash
# Usage: test.sh IMAGE
#
# Checks that ob runs as a non-root user and prints the version set in the
# Dockerfile. The Dockerfile already checks that better-sqlite3 loads.
set -euo pipefail

image=$1
want=$(sed -n 's/^ARG OBSIDIAN_HEADLESS_VERSION=//p' "$(dirname "$0")/Dockerfile")
got=$(docker run --rm --user 1000:1000 "$image" --version)

if [ "$got" != "$want" ]; then
	echo "FAIL: ob --version printed '$got', want '$want'" >&2
	exit 1
fi

echo "obsidian-headless: OK"
