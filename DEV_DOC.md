# Developer Documentation

This document explains how to set up, build, run and modify the Inception stack. For simple
usage of the running site, see `USER_DOC.md`.

---

## 1. Repository layout

```
inception/
├── Makefile                       ← entry point, calls docker compose
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore                     ← MUST ignore srcs/.env and secrets/
└── srcs/
    ├── .env                       ← all variables (never committed)
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/              ← mariadb.sh + server .cnf
        │   └── tools/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/              ← ssl.sh
        │   └── tools/
        └── wordpress/
            ├── Dockerfile
            ├── conf/              ← word.sh
            └── tools/
```

The `Makefile` is at the root and never calls `docker` directly on a container — it only
drives `docker compose -f ./srcs/docker-compose.yml`.

---

## 2. Setting up the environment from scratch

### 2.1 Prerequisites

Inside the virtual machine:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin make
sudo usermod -aG docker $USER      # then log out and back in
docker compose version             # must print v2.x
```

### 2.2 Local DNS

The stack answers on a domain name, not on `localhost`:

```bash
echo "127.0.0.1 abrami.42.fr" | sudo tee -a /etc/hosts
```

### 2.3 Host data directories

The two named volumes are backed by real host directories. The `Makefile` creates them, but
they can be created by hand:

```bash
mkdir -p /home/abrami/data/mariadb /home/abrami/data/wordpress
```

### 2.4 The `.env` file

`docker compose` automatically loads `srcs/.env` because it sits next to the compose file.
Create it with these variables:

```dotenv
DOMAIN_NAME=abrami.42.fr

# ── MariaDB ────────────────────────────────
DB_HOST=mariadb
DB_NAME=inception
DB_USER=abrami
DB_PASS=<database password>
DB_ROOT_PASSWORD=<root password>

# ── WordPress site ─────────────────────────
WP_TITLE=1337 Inception

# administrator — the name must not contain admin/administrator
WP_ADMIN_USER=abrami_manager
WP_ADMIN_PASS=<admin password>
WP_ADMIN_EMAIL=abrami@student.1337.ma

# second user, role "author"
WP_USER=abrami
WP_USER_PASS=<user password>
WP_USER_EMAIL=hello@hello.com
```

### 2.5 Keeping credentials out of git

`.gitignore` at the root of the repository:

```gitignore
srcs/.env
.env
secrets/
*.log
```

Verify before every push — a single committed password fails the project:

```bash
git check-ignore -v srcs/.env       # must print a matching rule
git log -p -- srcs/.env             # must return nothing
```

If `.env` was committed once, removing it in a later commit is **not** enough — the value
stays in the history and must be considered compromised (rewrite history, and rotate the
password).

### 2.6 Optional hardening — Docker secrets

Environment variables are readable through `docker inspect` and `/proc/<pid>/environ`, and
are inherited by every child process. Docker secrets are mounted as read-only files in a
tmpfs under `/run/secrets/` and avoid both problems. Migration is local:

```yaml
# docker-compose.yml
secrets:
  db_password:
    file: ../secrets/db_password.txt

services:
  mariadb:
    secrets: [db_password]
    environment:
      DB_PASS_FILE: /run/secrets/db_password
```

```bash
# entrypoint script
DB_PASS="$(cat "$DB_PASS_FILE")"
```

---

## 3. Building and launching

### 3.1 With the Makefile

```bash
make            # = make up : mkdir data dirs, build images, start detached
make build      # build the three images only
make down       # stop and remove containers + network
make clean      # down -v --rmi all
make fclean     # clean + rm -rf /home/abrami/data
make re         # fclean + full rebuild
```

### 3.2 The equivalent compose commands

Useful when debugging one service:

```bash
cd srcs

docker compose up -d --build          # build + start everything
docker compose up --build             # same, in the foreground with live logs
docker compose build --no-cache nginx # force a full rebuild of one image
docker compose up -d --force-recreate wordpress
docker compose ps
docker compose logs -f wordpress
docker compose down -v                # also removes the named volumes
```

### 3.3 What happens on the first `make`

```
make
 │
 ├─▶ mkdir -p /home/abrami/data/{mariadb,wordpress}
 │
 ├─▶ docker compose build ────────── 3 images from debian:bookworm
 │
 └─▶ docker compose up -d
        │
        ├── mariadb starts
        │     entrypoint mariadb.sh
        │       ├─ mariadb-install-db      (only if /var/lib/mysql/mysql is absent)
        │       ├─ mysqld &                temporary server
        │       ├─ CREATE DATABASE / USER / GRANT
        │       ├─ mysqladmin shutdown
        │       └─ exec mysqld             ← becomes PID 1
        │
        ├── wordpress starts (depends_on mariadb)
        │     entrypoint word.sh
        │       ├─ download + extract WordPress   (only if wp-load.php is absent)
        │       ├─ chown www-data
        │       ├─ wait loop: mysqladmin ping -h mariadb
        │       ├─ wp config create               (only if wp-config.php is absent)
        │       ├─ wp core install + wp user create
        │       ├─ write php-fpm pool (listen 0.0.0.0:9000)
        │       └─ exec php-fpm8.2 -F             ← becomes PID 1
        │
        └── nginx starts (depends_on wordpress)
              entrypoint ssl.sh
                ├─ openssl req -x509  → we.crt / we.key
                ├─ generate /etc/nginx/conf.d/default.conf (TLS 1.2 + 1.3)
                ├─ nginx -t
                └─ exec nginx -g "daemon off;"    ← becomes PID 1
```

Every step is guarded by an existence test, so a second `make` on existing volumes skips
initialisation and starts in seconds.

### 3.4 The `exec "$@"` rule

Each entrypoint ends with `exec "$@"`, which replaces the shell process with the command
given in `CMD`. This matters for three reasons:

1. The real service becomes **PID 1**, so `docker stop` delivers `SIGTERM` to it and it shuts
   down cleanly instead of being killed after the 10-second timeout.
2. If the service dies, the container exits, and the `restart` policy can restart it. With a
   shell as PID 1 the container would stay "up" while the service is dead.
3. No zombie processes are left behind by an intermediate shell.

This is also why no `tail -f`, `sleep infinity`, `while true` or `bash` is used to keep a
container alive — those are explicitly forbidden by the subject, and they hide failures.

---

## 4. Managing containers and volumes

### Containers

```bash
docker ps -a                                # all containers and their state
docker logs -f nginx                        # follow one service's output
docker exec -it wordpress bash              # shell inside a container
docker exec -it mariadb mariadb -u abrami -p inception
docker inspect nginx | less                 # full configuration
docker stats                                # live CPU / RAM per container
docker top mariadb                          # confirm PID 1 is mysqld
```

### Network

```bash
docker network ls
docker network inspect srcs_inception       # which containers, which IPs
docker exec -it wordpress getent hosts mariadb   # DNS resolution by service name
```

Only `443` is published. `3306` and `9000` exist inside the bridge only — confirm from the
host:

```bash
ss -lntp | grep -E ':443|:3306|:9000'       # only 443 must appear
```

### Volumes

```bash
docker volume ls
docker volume inspect srcs_wordpress        # shows Mountpoint and driver options
docker compose down -v                      # remove containers AND volumes
```

### Images

```bash
docker images                               # nginx:1.0, wordpress:1.0, mariadb:1.0
docker history wordpress:1.0                # inspect the layers
docker system df                            # disk used by Docker
docker system prune -af --volumes           # nuclear cleanup of the whole daemon
```

---

## 5. Where the data lives and how it persists

### The two volumes

| Volume | Mounted in | Container path | Host path | Contains |
|---|---|---|---|---|
| `mariadb` | `mariadb` | `/var/lib/mysql` | `/home/abrami/data/mariadb` | Database files, InnoDB tablespaces, logs |
| `wordpress` | `wordpress` **and** `nginx` | `/var/www/html` | `/home/abrami/data/wordpress` | WordPress core, `wp-config.php`, themes, plugins, uploads |

The `wordpress` volume is deliberately mounted twice: php-fpm executes the `.php` files,
NGINX serves the static assets from the exact same directory. Without this, images and CSS
would return 404.

### How they are declared

```yaml
volumes:
  wordpress:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/abrami/data/wordpress
```

This is a **named volume** — Docker creates it, names it (`srcs_wordpress`), tracks it and
deletes it on `down -v` — whose backing storage is a directory we chose, as the subject
requires the data to be under `/home/login/data`. It is not a bind mount declared in a
service's `volumes:` list: the container references the volume by name, and Docker resolves
where the bytes actually live.

### Persistence matrix

| Action | Containers | Images | Volumes | Host data |
|---|---|---|---|---|
| `make stop` | stopped | kept | kept | kept |
| `make down` | removed | kept | kept | kept |
| `make clean` | removed | removed | **removed** | directory kept, emptied |
| `make fclean` | removed | removed | **removed** | **deleted** |

### Backup and restore

```bash
# Database dump
docker exec mariadb mariadb-dump -u abrami -p"$DB_PASS" inception > backup.sql

# Site files
tar czf wordpress-files.tgz -C /home/abrami/data/wordpress .

# Restore the database into a running stack
docker exec -i mariadb mariadb -u abrami -p"$DB_PASS" inception < backup.sql
```

---

## 6. Modifying the project

| Change | What to run |
|---|---|
| Edited a `Dockerfile` | `docker compose build <service> && docker compose up -d <service>` |
| Edited an entrypoint script (`.sh`) | Same as above — scripts are `COPY`-ed into the image |
| Edited `.env` | `make down && make` — variables are read at container creation |
| Edited `.env` values used only at install (WP users, DB name) | `make fclean && make` — they are applied once, on first install |
| Added a service | New folder in `requirements/`, new `Dockerfile`, new block in `docker-compose.yml` |

Useful check after any compose edit:

```bash
docker compose -f srcs/docker-compose.yml config     # renders the file with variables resolved
```

This is the fastest way to catch an unset variable: anything that prints as an empty string
is a variable missing from `.env`.

---

## 7. Debugging checklist

| Symptom | Where to look |
|---|---|
| A container restarts in a loop | `docker logs <name>` — the entrypoint is failing; `set -e` aborts on the first error |
| `Error establishing a database connection` | `docker exec -it wordpress mariadb-admin ping -h mariadb`; check `bind-address` is `0.0.0.0` in the MariaDB config, and that `DB_USER`/`DB_PASS` match |
| NGINX returns 502 | php-fpm is not listening: `docker exec -it wordpress ss -lntp \| grep 9000` |
| NGINX returns 404 on a `.php` file | The `wordpress` volume is not mounted in nginx, or `root` does not point to `/var/www/html` |
| `nginx -t` fails at start | Syntax error in the config generated by `ssl.sh` — read the container logs |
| A variable is empty inside the container | `docker compose config`, then `docker exec <name> env` |
| Volume mounted empty | The host directory does not exist — `mkdir -p /home/abrami/data/{mariadb,wordpress}` and recreate the volume |
| TLS handshake fails | `openssl s_client -connect abrami.42.fr:443 -tls1_2` — check `ssl_protocols` and that the certificate files exist |