*This project has been created as part of the 42 curriculum by abrami.*

# Inception

## Description

**Inception** is a system-administration project whose goal is to build a small, complete
web infrastructure from scratch using **Docker** and **Docker Compose**, inside a virtual
machine.

Nothing is pulled ready-made from Docker Hub: every image is written by hand from a
Debian base, every service runs in its own dedicated container, and the containers talk to
each other over a private Docker bridge network. The only door into the infrastructure is
NGINX, listening on port **443** with **TLSv1.2 / TLSv1.3** only.

The stack serves a WordPress site reachable at **https://abrami.42.fr**.

### The three services

| Service | Role | Base image | Exposed |
|---|---|---|---|
| **nginx** | TLS reverse proxy, serves static files, forwards `.php` to php-fpm | `debian:bookworm` | `443` → host |
| **wordpress** | WordPress + php-fpm 8.2 (no web server inside) | `debian:bookworm` | `9000` (internal only) |
| **mariadb** | Database engine holding the WordPress database | `debian:bookworm` | `3306` (internal only) |

### Architecture

```
                          HOST MACHINE
   ┌──────────────────────────────────────────────────────────────┐
   │                                                              │
   │  Browser ──── https://abrami.42.fr:443 ────┐                 │
   │  (/etc/hosts → 127.0.0.1)                  │                 │
   │                                            ▼                 │
   │   ╔══════════════════ docker network: inception (bridge) ══╗  │
   │   ║                                                        ║  │
   │   ║   ┌────────────┐   fastcgi     ┌──────────────┐        ║  │
   │   ║   │   nginx    │──:9000───────▶│  wordpress   │        ║  │
   │   ║   │  TLS 1.2/3 │               │   php-fpm    │        ║  │
   │   ║   └─────┬──────┘               └──────┬───────┘        ║  │
   │   ║         │  reads static files         │ mysql :3306    ║  │
   │   ║         │                             ▼                ║  │
   │   ║         │                      ┌──────────────┐        ║  │
   │   ║         │                      │   mariadb    │        ║  │
   │   ║         │                      └──────┬───────┘        ║  │
   │   ╚═════════╪═════════════════════════════╪════════════════╝  │
   │             │                             │                   │
   │      volume │ wordpress            volume │ mariadb           │
   │             ▼                             ▼                   │
   │   /home/abrami/data/wordpress   /home/abrami/data/mariadb     │
   └──────────────────────────────────────────────────────────────┘
```

Only port **443** crosses the host boundary. `9000` and `3306` are never published — they
exist only inside the `inception` network.

## Instructions

### Prerequisites

* A Linux virtual machine with `docker`, `docker compose` (v2) and `make` installed.
* Your user must be able to run Docker (member of the `docker` group, or use `sudo`).
* The domain must resolve locally. Add this line to `/etc/hosts` on the VM:

```bash
echo "127.0.0.1 abrami.42.fr" | sudo tee -a /etc/hosts
```

### Configuration

Create `srcs/.env` (it is **not** committed to git). See `DEV_DOC.md` for the full list of
variables.

### Build and run

```bash
make          # create host data dirs, build the 3 images, start the stack
```

Then open **https://abrami.42.fr** in a browser. The certificate is self-signed, so the
browser will warn once — accept it.

| Command | Effect |
|---|---|
| `make` / `make up` | Build if needed and start all containers in the background |
| `make build` | Build the three images only |
| `make stop` | Stop the containers, keep them and the data |
| `make down` | Stop and remove containers and the network |
| `make restart` | Restart the running containers |
| `make clean` | `down` + remove volumes and images |
| `make fclean` | `clean` + delete `/home/abrami/data` on the host |
| `make re` | `fclean` then full rebuild |

## Project description

### Why Docker here

Each service is packaged with exactly the dependencies it needs and nothing else. The
image is a reproducible build recipe (the `Dockerfile`), so the whole infrastructure can be
destroyed and recreated identically with a single command. That is the point of the
exercise: infrastructure described as files in a git repository rather than as manual steps
on a server.

### Sources used in the project

| Element | Where it comes from |
|---|---|
| Base OS | Official `debian:bookworm` (Debian 12 — penultimate stable, Debian 13 "trixie" being current) |
| NGINX, PHP-FPM 8.2, MariaDB server, `mariadb-client` | Debian `apt` repositories |
| WordPress core | Downloaded from `wordpress.org` and installed by `wp-cli` |
| `wp-cli` | Official `wp-cli.phar` from the wp-cli GitHub builds branch |
| TLS certificate | Generated at container start with `openssl req -x509` (self-signed) |

### Main design choices

1. **One process per container, PID 1 is the service itself.** Every entrypoint script ends
   with `exec "$@"`, so the shell is *replaced* by the real daemon (`nginx -g "daemon off;"`,
   `php-fpm8.2 -F`, `mysqld`). No `tail -f`, no `sleep infinity`, no background loop. Signals
   from `docker stop` reach the actual service, and a crash makes the container exit so the
   `restart` policy can do its job.

2. **Configuration is generated at runtime, not baked into the image.** `ssl.sh` writes the
   NGINX server block and generates the certificate from `$DOMAIN_NAME`; `word.sh` creates
   `wp-config.php` from the database variables. Consequence: **no password is ever written
   into a Dockerfile or into an image layer**.

3. **Explicit dependency ordering *and* real readiness checks.** `depends_on` only
   guarantees start order, not that a service is ready. So `word.sh` polls the database with
   `mysqladmin ping` in a loop until MariaDB actually answers before running `wp config
   create`.

4. **Two-phase MariaDB bootstrap.** `mariadb.sh` starts a temporary server in the
   background, creates the database, the user and the grants, then shuts it down cleanly —
   only then does `exec "$@"` launch the real long-running `mysqld` as PID 1. Initialisation
   is idempotent: it is skipped if `/var/lib/mysql/mysql` already exists.

5. **The two persistent volumes are shared where needed.** The `wordpress` volume is
   mounted in *both* the wordpress and nginx containers: php-fpm executes the PHP files,
   NGINX serves the static ones (CSS, images, uploads) from the same directory.

### Virtual Machines vs Docker

| | Virtual Machine | Docker container |
|---|---|---|
| What is virtualised | The **hardware** (a hypervisor emulates CPU, RAM, disks) | The **operating system** (namespaces + cgroups isolate processes) |
| Kernel | Its own full guest kernel | Shares the host kernel |
| Weight | GB, boots in tens of seconds | MB, starts in milliseconds |
| Isolation | Very strong — a compromised guest kernel is still trapped in the VM | Weaker — a kernel exploit reaches the host |
| Typical use | Running a different OS, strong tenant separation | Packaging and shipping one application |

Both are used here, and that is deliberate: the VM gives us a disposable, isolated machine
to work on, and inside it Docker gives us three lightweight, reproducible services. A
container is **not** a small VM — it is a process tree with a private view of the system,
which is exactly why running it as a daemon with an artificial infinite loop is wrong.

### Secrets vs Environment Variables

| | Environment variables (`.env`) | Docker secrets |
|---|---|---|
| Storage | Plain text file on the host, injected into the container env | Files mounted read-only under `/run/secrets/` (tmpfs, in RAM) |
| Visibility | Visible in `docker inspect`, in `/proc/<pid>/environ`, often leaked into logs and child processes | Not in `docker inspect`, readable only inside the container |
| Scope | Inherited by **every** child process of the container | Read explicitly by the code that needs them |
| Rotation | Requires recreating the container | The file can be replaced |

This project uses a **git-ignored `srcs/.env` file**, which the subject makes mandatory, for
all non-sensitive configuration (domain, database name, users, site title) and for the
passwords. `.env` is listed in `.gitignore`, so **no credential ever reaches the git
repository** — which is the hard requirement. Docker secrets remain the stronger option for
the passwords, because they keep the value out of the process environment entirely; the
entrypoint scripts are written so that switching a variable to a `_FILE` counterpart is a
small, local change.

### Docker Network vs Host Network

| | `network_mode: host` | User-defined bridge (`inception`) |
|---|---|---|
| Network namespace | Shared with the host | Private to the containers |
| Port conflicts | Every container port occupies a host port | Only what is in `ports:` is published |
| Service discovery | `localhost` everywhere | Built-in DNS: `mariadb`, `wordpress` resolve to container IPs |
| Attack surface | MariaDB's 3306 and php-fpm's 9000 would be reachable on the host | Only `443` is reachable |

`host` mode (and the legacy `--link`) is forbidden by the subject, and for good reason: the
whole security model of this project depends on the fact that **only NGINX is reachable
from outside**. The user-defined bridge also provides automatic DNS resolution by service
name, which is why `word.sh` can simply connect to the host named `mariadb`.

### Docker Volumes vs Bind Mounts

| | Bind mount (`- ./src:/var/www/html`) | Named volume |
|---|---|---|
| Managed by | You — an arbitrary host path | Docker — listed by `docker volume ls` |
| Lifecycle | Independent of Docker | Tied to the project, removed with `down -v` |
| Portability | Breaks if the host path does not exist | Created automatically |
| Typical use | Injecting source code during development | Persisting application data in production |

The project uses **named volumes** (`mariadb` and `wordpress`), declared in the `volumes:`
section and managed by Docker. Because the subject also requires the data to live under
`/home/abrami/data`, they are declared with the `local` driver and a `device` option
pointing at that directory. The result is still a *named* volume — Docker creates it, names
it, tracks it and destroys it — but its backing store is a directory we chose, which is what
makes the data inspectable from the host and survivable across `docker compose down`.

## Resources

**Docker**
* Docker documentation — [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
* Docker documentation — [Compose file reference](https://docs.docker.com/reference/compose-file/)
* Docker documentation — [Volumes](https://docs.docker.com/engine/storage/volumes/) and [Networking](https://docs.docker.com/engine/network/)
* [Docker and the PID 1 zombie reaping problem](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/) — why `exec` matters

**Services**
* [NGINX — ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html) and [FastCGI module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
* [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
* [WP-CLI command reference](https://developer.wordpress.org/cli/commands/)
* [MariaDB — mariadb-install-db](https://mariadb.com/kb/en/mariadb-install-db/)
* [OpenSSL `req`](https://docs.openssl.org/master/man1/openssl-req/)

**Use of AI**

AI was used as a documentation assistant and a reviewer, never as a code generator for the
core of the project:

* **Explaining concepts** — clarifying the difference between `ENTRYPOINT` and `CMD`, why
  `exec "$@"` is required for PID 1 signal handling, and how Docker's `local` volume driver
  behaves with the `device` option.
* **Reviewing configuration** — a critical read of `docker-compose.yml`, the entrypoint
  scripts and the Dockerfiles against the subject's constraints, which surfaced points to
  verify (variable substitution, TLS protocol list, restart policy).
* **Drafting documentation** — a first structure for this `README.md`, `USER_DOC.md` and
  `DEV_DOC.md`, then rewritten and verified against the actual behaviour of the stack.

Every suggestion was tested on the VM before being kept, and every file in this repository
is understood and defendable line by line.
