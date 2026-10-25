# Installed and run on the same Node image, so better-sqlite3's native addon
# is built for the runtime's ABI. Bun reports a newer Node version than this
# runtime since Bun 1.4, so an addon it builds does not load here.
FROM node:24.22.1-alpine3.23 AS build

# For building better-sqlite3 when no prebuilt addon matches.
RUN apk add --no-cache \
	python3 \
	make \
	g++

# renovate: datasource=npm depName=obsidian-headless
ARG OBSIDIAN_HEADLESS_VERSION=0.0.14

RUN npm install --global obsidian-headless@${OBSIDIAN_HEADLESS_VERSION}

FROM node:24.22.1-alpine3.23

RUN apk add --no-cache \
	dumb-init

COPY --from=build /usr/local/lib/node_modules/obsidian-headless /usr/local/lib/node_modules/obsidian-headless

ENV HOME=/config \
	XDG_CONFIG_HOME=/config

RUN ln -s ../lib/node_modules/obsidian-headless/cli.js /usr/local/bin/ob \
	&& install -d -m 0777 /vaults /config

WORKDIR /vaults

ENTRYPOINT ["dumb-init", "--", "ob"]
CMD ["sync", "--continuous"]
