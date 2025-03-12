# ---- Base Node ----
FROM node:lts AS build

WORKDIR /app

RUN set -eux \
  && apt-get update \
  && apt install -y git 

COPY package*.json ./

RUN set -eux \
  && npm install

COPY . .

# TODO: run generate-list.js, need fix for recusive submodules
RUN set -eux \
  && npx vue-tsc -b && npx vite build

FROM node:lts AS runner

COPY --from=build /app/dist /app

RUN set -eux \
  && npm install -g wrangler@latest \
  && groupadd -g 1001 burnt \
  && useradd -u 1001 -g 1001 burnt \
  && chown -R burnt:burnt /app

WORKDIR /app
USER burnt

CMD [ "wrangler", "pages", "dev", "./", "--compatibility-flags", "nodejs_compat", "--show-interactive-dev-session", "false", "--ip", "0.0.0.0", "--port", "3000" ]
