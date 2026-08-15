# Developer documentation

How to set up, build, run and modify the Inception stack. For everyday use of the running site,
see `USER_DOC.md`.

---

## 1. Repository layout

```
inception/
├── Makefile                     ← entry point, drives docker compose
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore                   ← must ignore srcs/.env
└── srcs/
    ├── .env                     ← all variables, never committed
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   └── conf/
        │       └── mariadb.sh
        ├── nginx/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   └── conf/
        │       ├── ssl.sh
        │       └── default.conf
        └── wordpress/
            ├── Dockerfile
            ├── .dockerignore
            └── conf/
                ├── word.sh
                └── www.conf
```

The `Makefile` sits at the root and never runs `docker` against a container directly — it only
drives `docker compose -f ./srcs/docker-compose.yml`.

---

## 2. Setting up from scratch

### 2.1 Prerequisites

Inside the virtual machine:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin make
sudo usermod -aG docker $USER      # log out and back in afterwards
docker compose version             # must print v2.x
```

### 2.2 Local DNS

```bash
echo "127.0.0.1 abrami.42.fr" | sudo tee -a /etc/hosts
```

### 2.3 Host data directories

The two named volumes are backed by real directories. `make` creates them, but they can be made
by hand:

```bash
mkdir -p /home/abrami/data/mariadb /home/abrami/data/wordpress
```

The directories must exist before the containers start. A `device:` path that does not exist
makes the mount fail with an error that does not obviously point at the cause.

### 2.4 The `.env` file

Compose loads `srcs/.env` automatically because it sits beside the compose file. Create it with:

```dotenv
LOGIN=abrami
DOMAIN_NAME=abrami.42.fr

# MariaDB
DB_HOST=mariadb
DB_NAME=inception
DB_USER=abrami
DB_PASS=<database password>
DB_ROOT_PASSWORD=<root password>

# WordPress
WP_TITLE=1337 Inception

# administrator — the name must not contain admin or administrator
WP_ADMIN_USER=abrami_manager
WP_ADMIN_PASS=<admin password>
WP_ADMIN_EMAIL=abrami@student.1337.ma

# second user, role author
WP_USER=abrami
WP_USER_PASS=<user password>
WP_USER_EMAIL=hello@hello.com
```

`LOGIN` exists because the volume `device:` paths and the `Makefile` both need the same username.
Using the shell's `$USER` instead would silently resolve to `root` whenever anything runs under
`sudo`, sending the volumes to `/home/root/data`.

### 2.5 Keeping credentials out of git

`.gitignore` at the repository root:

```gitignore
srcs/.env
.env
secrets/
*.log
```

Verify before every push:

```bash
git check-ignore -v srcs/.env      # must print a matching rule
git log --all --full-history -- srcs/.env    # must return nothing
git log -p --all | grep -iE "pass|secret"    # must return nothing
```

A file removed in a later commit is still readable in the history. If `.env` was ever committed,
removing it now is not enough — the history must be rewritten and the passwords treated as
compromised.

### 2.6 Migrating to Docker secrets

The subject makes `.env` mandatory and strongly recommends Docker secrets for confidential
values. The current setup passes passwords as environment variables. Moving to secrets is a
local change in three places:

```yaml
# docker-compose.yml
secrets:
  db_password:
    file: ../secrets/db_password.txt

services:
  mariadb:
    secrets:
      - db_password
```

```bash
# entrypoint script
DB_PASS="$(cat /run/secrets/db_password)"
```

Non-secret configuration — the domain, database name, usernames, site title — stays in `.env`.

---

## 3. Building and launching

### 3.1 With the Makefile

```bash
make            # mkdir the data directories, build the images, start detached
make build      # build the three images only
make down       # stop and remove containers and the network
make clean      # down -v --rmi all
make fclean     # clean, then rm -rf /home/abrami/data
make re         # fclean followed by a full rebuild
```

### 3.2 The equivalent Compose commands

Useful when debugging one service:

```bash
cd srcs
docker compose up -d --build              # build and start everything
docker compose up --build                 # same, foreground, live logs
docker compose build --no-cache nginx     # force a full rebuild of one image
docker compose up -d --force-recreate wordpress
docker compose ps
docker compose logs -f wordpress
docker compose config                     # render the file with variables resolved
```

`docker compose config` is the fastest way to catch an unset variable — anything that renders as
an empty string is missing from `.env`.

### 3.3 What happens on the first `make`

```
make
 │
 ├─▶ mkdir -p /home/abrami/data/{mariadb,wordpress}
 │
 ├─▶ docker compose build ─────── 3 images from debian:bookworm
 │
 └─▶ docker compose up -d
        │
        ├── mariadb        ENTRYPOINT /mariadb.sh
        │     ├─ mkdir /run/mysqld, chown to mysql
        │     ├─ if /var/lib/mysql/mysql absent → mariadb-install-db
        │     ├─ if /var/lib/mysql/$DB_NAME absent:
        │     │    ├─ mysqld &                    temporary server
        │     │    ├─ wait for mariadb-admin ping
        │     │    ├─ CREATE DATABASE / CREATE USER / GRANT
        │     │    └─ mariadb-admin shutdown
        │     └─ exec mysqld                      ← becomes PID 1
        │
        ├── wordpress      ENTRYPOINT /word.sh    (depends_on mariadb)
        │     ├─ if wp-load.php absent → wp core download
        │     ├─ wait loop: mysqladmin ping -h mariadb -u $DB_USER
        │     ├─ if wp-config.php absent → wp config create
        │     ├─ if not installed → wp core install, wp user create
        │     ├─ chown -R www-data:www-data /var/www/html
        │     └─ exec php-fpm8.2 -F               ← becomes PID 1
        │
        └── nginx          ENTRYPOINT /ssl.sh     (depends_on wordpress)
              ├─ if we.crt absent → openssl req -x509
              ├─ nginx -t
              └─ exec nginx -g "daemon off;"      ← becomes PID 1
```

Every step is guarded by an existence test, so a second `make` on populated volumes skips
initialisation entirely.

Confirming the guards actually fire is worth doing after any change to the MariaDB image: a clean
`make re` must print `INIT DB` in `docker logs mariadb`. If it does not, the datadir was
pre-populated — see the note in section 6.

### 3.4 Configuration files: build time versus run time

Knowing which is which matters when deciding what to rebuild.

| File | How it reaches the container | Changing it requires |
|---|---|---|
| `default.conf` | `COPY` into `/etc/nginx/conf.d/` at build | `docker compose build nginx` |
| `www.conf` | `COPY` into `/etc/php/8.2/fpm/pool.d/` at build | `docker compose build wordpress` |
| `*.sh` entrypoints | `COPY` at build | Rebuild the image |
| TLS certificate | Generated by `ssl.sh` at container start | Restart the container after deleting `we.crt` |
| `wp-config.php` | Generated by `word.sh` at first start | `make fclean && make` |
| `.env` values | Injected by Compose at container creation | `make down && make` |

### 3.5 Why every entrypoint ends with `exec`

`exec` replaces the shell process image with the daemon instead of forking a child. The daemon
therefore inherits PID 1, which has three consequences:

1. `docker stop` sends SIGTERM to PID 1, so the service performs a clean shutdown rather than
   being killed after the grace period. For MariaDB in particular, that is the difference between
   a clean shutdown and InnoDB recovery on the next start.
2. If the service dies, PID 1 dies, the container exits, and the restart policy can act. With a
   shell as PID 1 the container would stay "up" while the service behind it was dead.
3. No intermediate shell remains to accumulate zombie children.

Each daemon is also started in the foreground — `daemon off` for NGINX, `-F` for php-fpm, plain
`mysqld` rather than `mysqld_safe`. A container has no init system to supervise a backgrounded
process, so a daemonising service would exit immediately and take the container with it. This is
also why none of the forbidden keep-alive tricks appear anywhere in the project.

---

## 4. Managing containers, network and volumes

### Containers

```bash
docker ps -a
docker logs -f nginx
docker exec -it wordpress bash
docker exec -it mariadb mariadb -u abrami -p inception
docker inspect nginx | less
docker stats
docker top mariadb                          # confirm PID 1 is mysqld
docker exec wordpress ps -o pid,comm        # confirm PID 1 is php-fpm
```

### Network

```bash
docker network ls
docker network inspect srcs_inception            # members and their IPs
docker exec -it wordpress getent hosts mariadb   # DNS by service name
```

Only 443 is published. Confirm from the host that nothing else is listening:

```bash
ss -lntp | grep -E ':443|:3306|:9000'            # only 443 must appear
```

### Volumes

```bash
docker volume ls
docker volume inspect srcs_wordpress             # shows Mountpoint and driver options
docker compose down -v                           # remove containers and volume objects
```

### Images

```bash
docker images                                    # nginx:1.0, wordpress:1.0, mariadb:1.0
docker history wordpress:1.0                     # inspect the layers
docker system df
docker system prune -af --volumes                # full daemon cleanup
```

---

## 5. Where the data lives and how it persists

### The two volumes

| Volume | Mounted in | Container path | Host path | Contents |
|---|---|---|---|---|
| `mariadb` | `mariadb` | `/var/lib/mysql` | `/home/abrami/data/mariadb` | Database files, InnoDB tablespaces, logs |
| `wordpress` | `wordpress` and `nginx` | `/var/www/html` | `/home/abrami/data/wordpress` | WordPress core, `wp-config.php`, themes, plugins, uploads |

The `wordpress` volume is mounted twice on purpose: php-fpm executes the PHP files, NGINX serves
static assets from the same directory. Without the shared mount, CSS and images return 404.

### Persistence matrix

| Action | Containers | Images | Volume objects | Files under `/home/abrami/data` |
|---|---|---|---|---|
| `make stop` | stopped | kept | kept | kept |
| `make down` | removed | kept | kept | kept |
| `make clean` | removed | removed | removed | **kept** |
| `make fclean` | removed | removed | removed | deleted |

The `make clean` row is the one that surprises people. `docker compose down -v` removes Docker's
volume objects, but these volumes are bind-backed: the bytes live in a directory Docker does not
own, so they survive. A subsequent `make` recreates the volumes pointing at the same populated
directory, and every initialisation guard sees existing data and skips. Only `make fclean` gives
a genuinely clean slate.

### Backup and restore

```bash
# Database dump
docker exec mariadb mariadb-dump -u abrami -p"$DB_PASS" inception > backup.sql

# Site files
tar czf wordpress-files.tgz -C /home/abrami/data/wordpress .

# Restore into a running stack
docker exec -i mariadb mariadb -u abrami -p"$DB_PASS" inception < backup.sql
```

---

## 6. Modifying the project

| Change | What to run |
|---|---|
| Edited a `Dockerfile` | `docker compose build <service> && docker compose up -d <service>` |
| Edited an entrypoint script | Same — scripts are `COPY`-ed into the image |
| Edited `default.conf` or `www.conf` | Same — both are build-time copies |
| Edited `.env` | `make down && make` |
| Edited an `.env` value used only at install (WordPress users, database name) | `make fclean && make` |
| Added a service | New directory under `requirements/`, new Dockerfile, new block in `docker-compose.yml` |

**One trap worth knowing.** Debian's `mariadb-server` package initialises a datadir during `apt
install`, so the image contains a populated `/var/lib/mysql`. Docker copies image content into an
empty named volume on first mount, which would make the initialisation guard in `mariadb.sh` see
a pre-existing datadir and skip the project's own bootstrap. The MariaDB Dockerfile therefore
clears the directory after installing the package. If `INIT DB` stops appearing in the logs after
a clean `make re`, that line has gone missing.

---

## 7. Debugging checklist

| Symptom | Where to look |
|---|---|
| A container restarts in a loop | `docker logs <name>` — the entrypoint is failing and `set -e` aborts on the first error |
| `wordpress` logs "Wait for mariadb" forever | The database user does not exist. `docker exec -it mariadb mariadb -e "SELECT user,host FROM mysql.user;"`. Usually leftover data in `/home/abrami/data/mariadb`; `make fclean && make` |
| "Error establishing a database connection" | `docker exec -it wordpress mariadb-admin ping -h mariadb`; confirm `--bind-address=0.0.0.0` and that `DB_USER` / `DB_PASS` match on both sides |
| NGINX returns 502 | php-fpm is not listening: `docker exec -it wordpress ss -lntp \| grep 9000` |
| NGINX returns 404 on a `.php` file | The `wordpress` volume is not mounted in nginx, or `root` does not point at `/var/www/html` |
| Sub-pages 404 but the home page works | The `location /` block with `try_files` is missing from `default.conf` |
| `nginx -t` fails at start | Syntax error in `default.conf`; the message is in `docker logs nginx` |
| A variable is empty inside a container | `docker compose config`, then `docker exec <name> env` |
| A volume mounts empty | The host directory does not exist. Create it and recreate the volume |
| Checking the TLS policy | `docker exec nginx nginx -T \| grep ssl_protocols`, and `nmap --script ssl-enum-ciphers -p 443 abrami.42.fr` for what the server actually negotiates |
| WordPress emits `http://` links on an HTTPS site | `wp core install` was given a URL without a scheme. Fix `word.sh` and reinstall, or update `siteurl` and `home` with `wp option update` |