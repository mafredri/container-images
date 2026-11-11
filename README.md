# Container images

My personal container images.

## Images

- `ghcr.io/mafredri/obsidian-headless`
- `ghcr.io/mafredri/rdap-fi-proxy`
- `ghcr.io/mafredri/rasexporter`
- `ghcr.io/mafredri/avahi`
- `ghcr.io/mafredri/caddy`
- `ghcr.io/mafredri/incus-debian`

## Local checks

[mise](https://mise.jdx.dev) installs the tools in `mise.toml` and runs the
checks:

```sh
mise run check
```

## Format

```sh
mise run fmt
```

## Targeted checks

```sh
mise run lint/sh
mise run lint/dockerfile
mise run renovate/check
```

## Local build

```sh
docker build -t ghcr.io/mafredri/rdap-fi-proxy:local images/rdap-fi-proxy
```

## Image tests

Each image directory has a `test.sh`. It takes an image reference, runs the
image, and exits non-zero if the image does not work. To build and test
images locally with Docker:

```sh
mise run test/images
mise run test/images avahi
```

## Publishing

`.github/workflows/images.yaml` picks the images to build from the files
that changed:

- Push to `main`: images with changes in `images/<name>/` are built, tested,
  and pushed. Changes to `test.sh` and `*.md` files do not count. Other
  images are not rebuilt, so their digests stay the same.
- Pull request: images with changes in `images/<name>/` are built and
  tested, but not pushed. If the pull request changes the workflow or
  `.github/scripts/changed-images.sh`, every image is built and tested.
- `v*` tag: every image is built, tested, and pushed.
- Manual run: the images listed in the `images` input, or every image if it
  is empty.

## Version updates

Renovate tracks:

- Docker base images in every `Dockerfile`
- GitHub Actions versions in `.github/workflows/*.yaml`
- Go modules in `images/rdap-fi-proxy`
- Dockerfile ARG app versions annotated with `# renovate: ...`
- CI tools in `mise.toml`
