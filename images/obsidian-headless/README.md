# obsidian-headless

Docker image for [Obsidian Headless](https://github.com/obsidianmd/obsidian-headless), a CLI client for Obsidian Sync.

## Setup

First, login to your Obsidian account:

```shell
docker run -it --rm \
    -v obsidian-config:/config \
    ghcr.io/mafredri/obsidian-headless login
```

List available remote vaults:

```shell
docker run -it --rm \
    -v obsidian-config:/config \
    ghcr.io/mafredri/obsidian-headless sync-list-remote
```

Set up a vault for syncing:

```shell
docker run -it --rm \
    -v obsidian-config:/config \
    -v /path/to/vault:/vaults \
    ghcr.io/mafredri/obsidian-headless sync-setup --vault "My Vault"
```

## Running

One-time sync:

```shell
docker run -it --rm \
    -v obsidian-config:/config \
    -v /path/to/vault:/vaults \
    ghcr.io/mafredri/obsidian-headless sync
```

Continuous sync (default):

```shell
docker run -d \
    -v obsidian-config:/config \
    -v /path/to/vault:/vaults \
    ghcr.io/mafredri/obsidian-headless
```

## Authentication via environment variable

For non-interactive use, set `OBSIDIAN_AUTH_TOKEN` instead of using `ob login`:

```shell
docker run -d \
    -e OBSIDIAN_AUTH_TOKEN=your-auth-token \
    -v obsidian-config:/config \
    -v /path/to/vault:/vaults \
    ghcr.io/mafredri/obsidian-headless
```

## Docker Compose

See [compose.yaml](compose.yaml).

To perform initial setup, use `docker compose run` which shares the same
volumes but allows interactive input:

```shell
docker compose run --rm obsidian-sync login
docker compose run --rm obsidian-sync sync-list-remote
docker compose run --rm obsidian-sync sync-setup --vault "My Vault"
```

Then start the service:

```shell
docker compose up -d
```

## Multiple vaults

Continuous sync only supports one vault per process. For multiple vaults,
run a service per vault with `--path` pointing to each subdirectory:

```shell
docker compose run --rm obsidian-sync sync-setup --vault "Work" --path /vaults/work
docker compose run --rm obsidian-sync sync-setup --vault "Personal" --path /vaults/personal
```

Then add a service per vault in your compose file, each with its own `command`:

```yaml
command: ['sync', '--continuous', '--path', '/vaults/work']
```
