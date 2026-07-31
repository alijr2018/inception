# DEV_DOC

## Environment setup from scratch
1. Install Docker Engine and Docker Compose plugin.
2. Clone repository.
3. Create local env file:
   - copy `/home/runner/work/inception/inception/srcs/.env.example` to `/home/runner/work/inception/inception/srcs/.env`
4. Fill variables in `.env`.
5. Ensure persistent directories exist on host:
   - `/home/<login>/data/mariadb`
   - `/home/<login>/data/wordpress`
6. Configure local DNS via `/etc/hosts` for `<login>.42.fr`.

## Build and launch
From repository root:
- `make` (build + up)
- `make build` (build only)
- `make down` (stop/remove stack)
- `make re` (clean + rebuild)

## Useful management commands
- `make ps`
- `make logs`
- `docker compose -f ./srcs/docker-compose.yml exec mariadb mariadb -u root -p`
- `docker compose -f ./srcs/docker-compose.yml exec wordpress wp user list --path=/var/www/html --allow-root`

## Persistence model
- Named volume `mariadb_data` stores `/var/lib/mysql` for MariaDB.
- Named volume `wordpress_data` stores `/var/www/html` for WordPress files.
- Both are configured through compose `driver_opts` to store data under `/home/<login>/data/...`.
