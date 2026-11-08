# Installed and run on the same Node image, so better-sqlite3's native addon
# is built for the runtime's ABI. Bun reports a newer Node version than this
# runtime since Bun 1.4, so an addon it builds does not load here.
FROM node:26.13.0-alpine3.23 AS build

# For building better-sqlite3 when no prebuilt addon matches.
RUN apk add --no-cache \
	python3 \
	make \
	g++

# renovate: datasource=npm depName=obsidian-headless
ARG OBSIDIAN_HEADLESS_VERSION=0.0.14

# npm runs no install scripts unless allowed, and better-sqlite3 fetches or
# builds its addon in one.
RUN npm install --global --allow-scripts=better-sqlite3 obsidian-headless@${OBSIDIAN_HEADLESS_VERSION}

FROM node:26.13.0-alpine3.23

RUN apk add --no-cache \
	dumb-init

COPY --from=build /usr/local/lib/node_modules/obsidian-headless /usr/local/lib/node_modules/obsidian-headless

ENV HOME=/config \
	XDG_CONFIG_HOME=/config

# Opening a database fails the build when the addon does not load on this
# Node.
RUN ln -s ../lib/node_modules/obsidian-headless/cli.js /usr/local/bin/ob \
	&& node -e 'const load = require("node:module").createRequire("/usr/local/lib/node_modules/obsidian-headless/cli.js"); new (load("better-sqlite3"))(":memory:").close()' \
	&& install -d -m 0777 /vaults /config

WORKDIR /vaults

ENTRYPOINT ["dumb-init", "--", "ob"]
CMD ["sync", "--continuous"]
