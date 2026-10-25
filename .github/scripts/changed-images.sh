#!/usr/bin/env bash
# Usage: changed-images.sh [--image-only] BASE HEAD [PATH...]
#
# Prints the images to build as a JSON array, for example ["avahi"]. An
# image is included when files under images/<name>/ differ between BASE and
# HEAD. Every image is included when:
#   - BASE is empty or all zeros, which GitHub sends for a new branch or tag,
#   - BASE is not in the local history, or
#   - one of the files in PATH changed.
#
# --image-only skips changes to test.sh and *.md files, because they are not
# copied into the image.
set -euo pipefail

image_only=false
if [ "${1:-}" = --image-only ]; then
	image_only=true
	shift
fi
base=$1
head=$2
shift 2

all=$(for dockerfile in images/*/Dockerfile; do
	basename "$(dirname "$dockerfile")"
done)

selected=$all
if [[ -n $base && ! $base =~ ^0+$ ]] && changed=$(git diff --name-only "$base...$head" 2>/dev/null); then
	if $image_only; then
		changed=$(grep -vE '^images/[^/]+/(test\.sh$|.*\.md$)' <<<"$changed" || true)
	fi
	selected=$(comm -12 <(printf '%s\n' "$all" | sort) \
		<(sed -n 's|^images/\([^/]*\)/.*|\1|p' <<<"$changed" | sort -u))
	for path in "$@"; do
		if grep -qxF "$path" <<<"$changed"; then
			selected=$all
		fi
	done
fi

jq -cn --arg names "$selected" '$names | split("\n") | map(select(. != ""))'
