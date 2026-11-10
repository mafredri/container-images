# caddy

[Caddy](https://caddyserver.com) with the
[Hurricane Electric DNS provider](https://github.com/caddy-dns/he)
(`dns.providers.he`), for ACME DNS challenges through dns.he.net's dynamic
TXT records.

Each `_acme-challenge` record holds one value and has its own DDNS key, so a
certificate for a name and one for its wildcard (`example.com` and
`*.example.com`) cannot both be issued through it: they share one TXT name.
Use names whose challenges have different TXT names, such as `example.com`
and `*.apps.example.com`, each with its own record and key:

```
example.com {
	tls {
		dns he {env.HE_KEY_EXAMPLE}
	}
}
```
