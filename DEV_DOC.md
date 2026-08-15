# Developer documentation

How to set up, build, run and modify the Inception stack. For everyday use of the running site,
see `USER_DOC.md`.

---

## 1. Repository layout

```
inception/
├── Makefile                     
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── .env                     
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   └── conf/
        │       └── mariadb.sh
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/
        │       ├── ssl.sh
        │       └── default.conf
        └── wordpress/
            ├── Dockerfile
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
DOMAIN_NAME=abrami.42.fr

# MariaDB
DB_HOST=mariadb
DB_NAME=inception
DB_USER=abrami
DB_PASS=<database password>

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

---
