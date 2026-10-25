#!/usr/bin/env bash
# Usage: test.sh IMAGE
#
# Creates a rasdaemon database with one memory error, starts the exporter
# on it, and checks that /metrics reports the error. This also checks that
# the SQLite driver, which uses cgo, works in the image.
set -euo pipefail

image=$1
name=rasexporter-test-$$
dir=$(mktemp -d)
trap 'docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$dir"' EXIT

python3 - "$dir/rasdaemon.db" <<'PY'
import datetime, sqlite3, sys

db = sqlite3.connect(sys.argv[1])
db.execute("""create table mc_event (id integer primary key, timestamp text,
    err_count integer, err_type text, err_msg text, label text, mc integer,
    top_layer integer, middle_layer integer, lower_layer integer,
    address integer, grain integer, syndrome integer, driver_detail text)""")
now = datetime.datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %z")
db.execute("insert into mc_event values (1, ?, 3, 'Corrected', 'memory scrubbing error',"
           " 'DIMM_A1', 0, 0, 0, -1, 102391808, 7, 0, 'test')", (now,))
db.commit()
PY
chmod 0644 "$dir/rasdaemon.db"

docker run -d --name "$name" -p 127.0.0.1::7010 -v "$dir/rasdaemon.db:/rasdaemon.db:ro" "$image" >/dev/null
port=$(docker port "$name" 7010/tcp | head -n1 | cut -d: -f2)

tries=30
until curl -fsS -o "$dir/metrics" "http://127.0.0.1:$port/metrics"; do
	tries=$((tries - 1))
	if [ "$tries" -eq 0 ]; then
		docker logs "$name" >&2 || true
		echo "FAIL: /metrics did not respond" >&2
		exit 1
	fi
	sleep 1
done

if ! grep -q '^ras_mc_events{.*label="DIMM_A1"' "$dir/metrics"; then
	docker logs "$name" >&2 || true
	echo "FAIL: /metrics does not include the test memory error" >&2
	exit 1
fi

echo "rasexporter: OK"
