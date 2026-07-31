# USER_DOC

## Provided services
- `nginx`: HTTPS entrypoint on port 443.
- `wordpress`: PHP-FPM and WordPress application runtime.
- `mariadb`: WordPress relational database.

## Start and stop
From `/home/runner/work/inception/inception`:
- Start/build: `make`
- Stop: `make stop`
- Tear down: `make down`
- Full cleanup (containers, volumes, caches): `make clean`

## Access website and admin
1. Configure `/etc/hosts` with `127.0.0.1 <login>.42.fr`.
2. Open `https://<login>.42.fr`.
3. Login to admin panel at `https://<login>.42.fr/wp-admin` using `WP_ADMIN_USER` and `WP_ADMIN_PASSWORD` from your local `.env`.

## Credentials management
- Credentials are defined in local file: `/home/runner/work/inception/inception/srcs/.env`.
- Start from `.env.example` and keep real values private.
- Do not commit real credentials to Git.

## Health checks
Useful commands:
- `make ps` to list container status.
- `make logs` for live logs.
- `docker compose -f ./srcs/docker-compose.yml logs mariadb`
- `docker compose -f ./srcs/docker-compose.yml logs wordpress`
- `docker compose -f ./srcs/docker-compose.yml logs nginx`
