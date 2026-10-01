# syntax=docker/dockerfile:1

# Production image: FrankenPHP (Caddy + PHP in one process) serving the app on :8080.
# TLS terminates in front of it (ingress / Cloudflare); all config comes from env vars.

ARG PHP_VERSION=8.4
ARG NODE_VERSION=24

# The build stages run on the builder's native platform: vendor/ and public/build are
# platform-independent, so multi-arch builds never run Composer or Vite under emulation.
FROM --platform=$BUILDPLATFORM node:${NODE_VERSION}-trixie-slim AS node

FROM --platform=$BUILDPLATFORM dunglas/frankenphp:1-php${PHP_VERSION}-trixie AS build

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN install-php-extensions @composer zip

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --no-progress --prefer-dist --no-scripts --no-autoloader

COPY package.json package-lock.json .npmrc ./
RUN npm ci --no-audit --no-fund

COPY . .

# PHP is needed for the asset build too: the Wayfinder Vite plugin runs `php artisan`.
RUN composer dump-autoload --no-dev --optimize \
    && npm run build

FROM dunglas/frankenphp:1-php${PHP_VERSION}-trixie AS app

RUN install-php-extensions pdo_pgsql intl \
    && cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

ENV SERVER_NAME=:8080 \
    LOG_CHANNEL=stderr

COPY . .
COPY --from=build /app/vendor ./vendor
COPY --from=build /app/bootstrap/cache ./bootstrap/cache
COPY --from=build /app/public/build ./public/build
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/app-entrypoint

# Code stays root-owned; only the runtime-writable paths belong to www-data.
RUN mkdir -p storage/app/private storage/app/public storage/framework/cache/data \
        storage/framework/sessions storage/framework/views storage/logs \
    && chown -R www-data:www-data storage bootstrap/cache /config/caddy /data/caddy

USER www-data

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/app-entrypoint"]
CMD ["frankenphp", "run", "--config", "/etc/frankenphp/Caddyfile", "--adapter", "caddyfile"]
