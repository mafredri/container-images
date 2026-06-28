# rdap-fi-proxy

Small RDAP-compatible proxy for uptime-kuma `.fi` domain expiry checks.

It accepts the RDAP paths Kuma calls, fetches Traficom RDAP, looks up the current `.fi` expiry from `whois.fi:43`, and returns the RDAP JSON with an `expiration` event added.

## Run

```sh
docker compose up --build
```

Local check:

```sh
curl -fsSL http://localhost:8080/rdap/rdap/domain/domain.fi | jq '.events'
```

Expected result includes an `expiration` event.

## Use with uptime-kuma

Recommended integration is the Node fetch preload in `kuma-fetch-override.js`. Add the proxy service to the same Compose project or network as Kuma, then add this to the Kuma service:

```yaml
services:
  uptime-kuma:
    environment:
      NODE_OPTIONS: "--require /app/data/rdap-fi/kuma-fetch-override.js"
      RDAP_FI_PROXY_PREFIX: "http://rdap-fi-proxy:8080/rdap/rdap/domain/"
    volumes:
      - ./kuma-fetch-override.js:/app/data/rdap-fi/kuma-fetch-override.js:ro
```

`compose.kuma-example.yaml` shows the complete shape.

## Why not redirect rdap.fi?

Kuma calls `https://rdap.fi/rdap/rdap/domain/<domain>`. DNS or `/etc/hosts` can redirect the IP, but TLS still requires a certificate valid for `rdap.fi` and trusted by the Kuma container. Using HTTP behind a DNS redirect will fail because Kuma still asks for HTTPS.

The preload avoids that by changing the URL inside the Kuma process before `fetch` opens a connection.

## Configuration

Environment variables:

| Name | Default | Meaning |
| --- | --- | --- |
| `ADDR` | `:8080` | HTTP listen address |
| `UPSTREAM_RDAP_URL` | `https://rdap.fi/rdap/rdap` | Official `.fi` RDAP base URL |
| `WHOIS_ADDR` | `whois.fi:43` | WHOIS server used for expiry |
| `HTTP_TIMEOUT` | `10s` | Upstream RDAP timeout |
| `WHOIS_TIMEOUT` | `10s` | WHOIS lookup timeout |
| `CACHE_TTL` | `6h` | In-memory expiry cache duration |

## Notes

The proxy only accepts `.fi` domains. WHOIS expiry timestamps are parsed in `Europe/Helsinki` and emitted as RFC 3339 timestamps, which Kuma's `new Date(eventDate)` accepts.

## First run after a failed .fi check

Kuma caches domain expiry checks in SQLite. If a `.fi` domain was checked before this proxy was active, the row can contain `expiry = Invalid Date` with a fresh `last_check`. In that state Kuma returns the stored value for up to one day and calls `sendNotifications()` without querying RDAP again.

That matches this log pattern:

```text
[RDAP] INFO: RDAP DNS data updated successfully
[DOMAIN_EXPIRY] WARN: No valid expiry date passed to sendNotifications for domain.fi (expiry: Invalid Date), skipping notification
```

Reset the cached row once, then resume the monitor:

```sh
docker compose stop uptime-kuma
docker compose run --rm --entrypoint sh uptime-kuma -lc 'sqlite3 /app/data/kuma.db "delete from domain_expiry where domain = '\''domain.fi'\'';"'
docker compose up -d uptime-kuma
```

If your Compose file mounts a different data directory, use the `kuma.db` path from Kuma's `Data Dir:` log line. The default Docker path is `/app/data/kuma.db`.

With the shim loaded, Kuma logs should include:

```text
[rdap-fi-proxy] fetch override loaded: https://rdap.fi/rdap/rdap/domain/ -> http://rdap-fi-proxy:8080/rdap/rdap/domain/
```

When Kuma actually queries `.fi`, it should include:

```text
[rdap-fi-proxy] rewritten RDAP request to http://rdap-fi-proxy:8080/rdap/rdap/domain/domain.fi
```

The proxy logs should include:

```text
msg="rdap request" domain=domain.fi
msg="rdap response enriched" domain=domain.fi expiration=...
```

If the preload line is missing, `NODE_OPTIONS` or the bind mount is not applied to the running Kuma container. If the preload line exists but there is no rewrite line, Kuma has not called RDAP yet, often because it is still using the cached `domain_expiry` row. Use the reset command above once for domains that already stored `Invalid Date`.
