# Container images

My personal container images.

## Images

- `ghcr.io/mafredri/obsidian-headless`
- `ghcr.io/mafredri/rdap-fi-proxy`
- `ghcr.io/mafredri/rasexporter`

## Local checks

```sh
make ci
```

## Format

```sh
make fmt
```

## Targeted checks

```sh
make lint/sh
make lint/dockerfile
make renovate/check
```

## Local build

```sh
docker build -t ghcr.io/mafredri/rdap-fi-proxy:local images/rdap-fi-proxy
```

## Version updates

Renovate tracks:

- Docker base images in every `Dockerfile`
- GitHub Actions versions in `.github/workflows/*.yaml`
- Go modules in `images/rdap-fi-proxy`
- Dockerfile ARG app versions annotated with `# renovate: ...`
