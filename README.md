# client-portal-v2

Client Portal v2: a single Laravel 13 app with a React 19 frontend through Inertia 3
(TypeScript, Tailwind CSS 4, shadcn/ui, Vite). Started from the official
[Laravel React starter kit](https://laravel.com/docs/starter-kits#react).

## Local development

Requires PHP 8.4, Composer and Node 24. On Windows,
[Laravel Herd](https://herd.laravel.com/windows) or the
[php.new installer](https://laravel.com/docs/installation#installing-php) sets up
PHP and Composer.

```bash
composer setup      # install dependencies, create .env and app key, migrate, build assets
composer dev        # run the app on http://localhost:8000 with Vite hot reload
composer ci:check   # lint, type checks and tests (same as CI)
```

Local development uses SQLite (`database/database.sqlite`); production uses PostgreSQL.

## Docker image

```bash
docker build -t client-portal-v2 .
```

The image serves the app with [FrankenPHP](https://frankenphp.dev) on port 8080
(plain HTTP; TLS terminates in front of it), runs as `www-data`, logs to stderr and
takes all configuration from environment variables. Config, routes and views are
cached when the container starts.

## CI

- `.github/workflows/tests.yml`: lint, type checks and tests on every push and pull request.
- `.github/workflows/docker.yml`: builds `linux/amd64` and `linux/arm64` images and
  pushes them to `ghcr.io/skill-wanderer/client-portal-v2`.

| Trigger        | Image tags                 |
| -------------- | -------------------------- |
| Push to `main` | `latest`, `sha-<commit>`   |
| Tag `v1.2.3`   | `1.2.3`, `sha-<commit>`    |
| Pull request   | Build only, nothing pushed |

## Deploying to k3s

Manifests are in `k8s/client-portal-v2` and use the `client-portal` namespace, next
to the existing `postgres` service.

1. Create the database and its user in PostgreSQL:

    ```sql
    CREATE ROLE client_portal_v2 LOGIN PASSWORD 'change-me';
    CREATE DATABASE client_portal_v2 OWNER client_portal_v2;
    ```

2. Copy `secret.yaml.example` to `secret.yaml` (git-ignored) and fill in `APP_KEY`
   (`echo "base64:$(openssl rand -base64 32)"`) and `DB_PASSWORD`.
3. Set the real hostname in `APP_URL` (`configmap.yaml`) and the image tag in
   `deployment.yaml` (`0.1.0` is what pushing a `v0.1.0` git tag produces).
4. Apply everything:

    ```bash
    kubectl apply -f k8s/client-portal-v2/
    ```

5. Route the public hostname to the `client-portal-v2` service on port 80.

Migrations run in an init container before each new version starts. The GHCR package
must be public (like `client-portal-be`) for k3s to pull it without credentials.
