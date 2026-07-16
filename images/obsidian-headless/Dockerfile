FROM oven/bun:1-alpine AS build

RUN apk add --no-cache \
	python3 \
	make \
	g++

# renovate: datasource=npm depName=obsidian-headless
ARG OBSIDIAN_HEADLESS_VERSION=0.0.13

ENV BUN_INSTALL=/usr/local

RUN bun install --global obsidian-headless@${OBSIDIAN_HEADLESS_VERSION}

# For now, using Node.js because better-sqlite3 is not supported in Bun.
# FROM oven/bun:1-alpine
FROM node:24.18.0-alpine3.23

RUN apk add --no-cache \
	dumb-init

COPY --from=build /usr/local/install/global /usr/local/install/global
COPY --from=build /usr/local/bin/ob /usr/local/bin/
COPY --from=build /usr/local/install/global/node_modules/obsidian-headless/package.json /usr/local/bin/package.json

ENV NODE_PATH=/usr/local/install/global/node_modules \
	HOME=/config \
	XDG_CONFIG_HOME=/config

RUN install -d -m 0777 /vaults /config

WORKDIR /vaults

ENTRYPOINT ["dumb-init", "--", "ob"]
CMD ["sync", "--continuous"]
