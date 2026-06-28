# RDAP .fi Proxy Research

## Observations

Uptime-kuma resolves RDAP servers from IANA bootstrap data in `server/model/domain_expiry.js`. The `.fi` bootstrap entry is `https://rdap.fi/rdap/rdap/`, and Kuma calls `https://rdap.fi/rdap/rdap/domain/<domain>`.

Kuma only treats an RDAP event with `eventAction: "expiration"` as an expiry date. The `.fi` RDAP response observed during investigation contained `registration`, but no `expiration`.

IANA's `.fi` delegation page lists:

- WHOIS server: `whois.fi`
- RDAP server: `https://rdap.fi/rdap/rdap/`

Traficom's public fi-domain search page says public information includes registration and expiration dates. The WHOIS service returns that expiration date directly. For a registered `.fi` domain, `whois.fi:43` returns an expiry line shaped like:

```text
expires............: 21.10.2026 02:37:36
```

`whois.nic.fi` appears in the RDAP `port43` field, but it did not resolve from this devcontainer. `whois.fi` did resolve and returned the expiration date.

## Override options considered

### 1. Persist a custom `rdapDnsData` setting

Kuma can read `rdapDnsData` from settings as an offline fallback, but current code first tries to fetch `https://data.iana.org/rdap/dns.json` and writes the result back to settings. This is not reliable when outbound IANA access works, because a restart or refresh can restore the official `rdap.fi` URL.

### 2. Replace `extra/rdap-dns.json`

This only affects the hardcoded fallback path. It has the same weakness as the settings approach because the normal path refreshes from IANA.

### 3. Redirect `rdap.fi` with DNS or `/etc/hosts`

Kuma requests `https://rdap.fi/...`. A DNS redirect changes the IP, but not the hostname or TLS requirements. The replacement service must present a certificate valid for `rdap.fi`, trusted by the Kuma container. That requires either a real certificate for a domain we do not control or a private CA installed into the container, plus the host mapping. This is possible but operationally brittle.

### 4. Patch Kuma source or image

A direct patch to `domain_expiry.js` can add an environment override for `.fi`. This is reliable, but it creates a forked image and upgrade work for every Kuma update.

### 5. Preload a small fetch override

Node supports `NODE_OPTIONS=--require <file>`. A preload file can wrap `globalThis.fetch` and rewrite only `https://rdap.fi/rdap/rdap/domain/...` to `http://rdap-fi-proxy:8080/rdap/rdap/domain/...`. This avoids TLS spoofing, avoids a source fork, and keeps the change local to the Kuma process.

Chosen approach: use the fetch override. It is the smallest reliable deployment change. The cost is that it depends on Kuma continuing to use global `fetch` for RDAP, which the inspected code currently does.

## Cache behavior found during live use

Kuma stores domain expiry rows in `domain_expiry`. In `DomainExpiry.checkExpiry()`, if `lastCheck` is less than one day old, Kuma returns the stored `bean.expiry` without calling RDAP. If the stored value is `Invalid Date`, `sendNotifications()` logs the warning and the proxy is not contacted.

A one-time delete of the affected `domain_expiry` row forces Kuma to call RDAP on the next monitor run.

## Preload dependency resolution

The preload may be mounted outside the Kuma app, for example `/rdap-fi/kuma-fetch-override.js`. In that case plain `require("redbean-node")` resolves from the preload directory and fails. Use `Module.createRequire(parent.filename)` from the module that loaded `domain_expiry.js` so dependencies resolve from Kuma's app tree.
