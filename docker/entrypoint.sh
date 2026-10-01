#!/bin/sh
set -e

# Cache config, routes, views and events from the real runtime env (ConfigMap + Secret),
# which only exists once the container starts, not when the image is built.
php artisan optimize

exec docker-php-entrypoint "$@"
