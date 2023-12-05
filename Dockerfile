# base
# ------------------------------------------------
FROM node:20-bookworm-slim as base

RUN apt-get update && apt-get install -y \
    openssl \
    && rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /home/node/app

COPY --chown=node:node .yarn/plugins .yarn/plugins
COPY --chown=node:node .yarn/releases .yarn/releases
COPY --chown=node:node .yarnrc.yml .
COPY --chown=node:node package.json .
COPY --chown=node:node api/package.json api/
COPY --chown=node:node web/package.json web/
COPY --chown=node:node yarn.lock .

RUN yarn install

COPY --chown=node:node redwood.toml .
COPY --chown=node:node graphql.config.js .
COPY --chown=node:node .env.defaults .env.defaults

# api build
# ------------------------------------------------
FROM base as api_build

# If your api side build relies on build-time environment variables,
# specify them here as ARGs. (But don't put secrets in your Dockerfile!)
#
# ARG MY_BUILD_TIME_ENV_VAR

COPY --chown=node:node api api
RUN yarn redwood build api


# web build
# ------------------------------------------------
FROM base as web_build

ARG SUPABASE_KEY
ARG SUPABASE_URL
ARG REACT_APP_PUBLIC_POSTHOG_KEY
ARG REACT_APP_PUBLIC_POSTHOG_HOST
ARG NOVU_ID

COPY --chown=node:node web web
RUN yarn redwood build web --no-prerender

# serve api
# ------------------------------------------------
FROM node:18-bookworm-slim as api_serve

RUN apt-get update && apt-get install -y \
    openssl \
    && rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /home/node/app

COPY --chown=node:node .yarn/plugins .yarn/plugins
COPY --chown=node:node .yarn/releases .yarn/releases
COPY --chown=node:node .yarnrc.yml .
COPY --chown=node:node api/package.json .
COPY --chown=node:node yarn.lock .

RUN --mount=type=cache,target=/home/node/.yarn/berry/cache,uid=1000 \
    --mount=type=cache,target=/home/node/.cache,uid=1000 \
    CI=1 yarn workspaces focus api --production

COPY --chown=node:node redwood.toml .
COPY --chown=node:node graphql.config.js .
COPY --chown=node:node .env.defaults .env.defaults

COPY --chown=node:node --from=api_build /home/node/app/api/dist /home/node/app/api/dist
COPY --chown=node:node --from=api_build /home/node/app/api/db /home/node/app/api/db
COPY --chown=node:node --from=api_build /home/node/app/node_modules/.prisma /home/node/app/node_modules/.prisma
# adding this allowed it to build
COPY --chown=node:node --from=api_build /home/node/app/node_modules /home/node/app/node_modules 

COPY --chown=node:node --from=web_build /home/node/app/web/dist /home/node/app/web/dist
COPY --chown=node:node .fly .fly

ENV NODE_ENV=production

ENTRYPOINT ["sh"]
CMD [".fly/start.sh"]