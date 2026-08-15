*This project has been created as part of the 42 curriculum by abrami.*

# Inception

## Description

Inception builds a small web infrastructure from scratch using Docker and Docker Compose,
inside a virtual machine. Three services — NGINX, WordPress with php-fpm, and MariaDB — each
run in their own container, are built from hand-written Dockerfiles on a Debian base, and
communicate over a private bridge network.


### The three services

| Service | Role | Base image | Listens on |
|---|---|---|---|
| `nginx` | TLS termination, serves static files, forwards `.php` over FastCGI | `debian:bookworm` | `443`, published to the host |
| `wordpress` | WordPress core run by php-fpm 8.2. No web server inside | `debian:bookworm` | `9000`, network-internal only |
| `mariadb` | Database engine holding the WordPress database | `debian:bookworm` | `3306`, network-internal only |

### Architecture

```
                              HOST MACHINE
   ┌───────────────────────────────────────────────────────────────┐
   │                                                               │
   │  Browser ───── https://abrami.42.fr ─────┐                    │
   │  (/etc/hosts → 127.0.0.1)                │ 443                │
   │                                          ▼                    │
   │   ╔═══════════ docker network: inception (bridge) ═════════╗   │
   │   ║                                                        ║   │
   │   ║   ┌────────────┐   fastcgi    ┌──────────────┐         ║   │
   │   ║   │   nginx    │──── 9000 ───▶│  wordpress   │         ║   │
   │   ║   │ TLS 1.2/3  │              │   php-fpm    │         ║   │
   │   ║   └─────┬──────┘              └──────┬───────┘         ║   │
   │   ║         │ static files               │ mysql 3306      ║   │
   │   ║         │                            ▼                 ║   │
   │   ║         │                     ┌──────────────┐         ║   │
   │   ║         │                     │   mariadb    │         ║   │
   │   ║         │                     └──────┬───────┘         ║   │
   │   ╚═════════╪════════════════════════════╪═════════════════╝   │
   │             │                            │                     │
   │      volume │ wordpress           volume │ mariadb             │
   │             ▼                            ▼                     │
   │   /home/abrami/data/wordpress   /home/abrami/data/mariadb      │
   └───────────────────────────────────────────────────────────────┘
```

Only 443 crosses the host boundary. Ports 9000 and 3306 exist only inside the `inception`
network and are never published.

## Instructions

### Prerequisites

* A Linux virtual machine with `docker`, the Compose v2 plugin, and `make`.
* Your user must be able to run Docker (member of the `docker` group).
* The domain must resolve locally:

```bash
echo "127.0.0.1 abrami.42.fr" | sudo tee -a /etc/hosts
```

### Configuration

Create `srcs/.env`. It is listed in `.gitignore` and is never committed. The full list of
variables is in `DEV_DOC.md`.

### Build and run

```bash
make
```

Then open `https://abrami.42.fr`. The certificate is self-signed, so the browser warns once —
accept it and continue.

| Command | Effect |
|---|---|
| `make` / `make up` | Create the host data directories, build the three images, start the stack detached |
| `make build` | Build the three images only |
| `make stop` | Stop the containers, keep them and all data |
| `make down` | Stop and remove the containers and the network |
| `make restart` | Restart the running containers |
| `make clean` | `down -v --rmi all` — removes containers, images and volume objects |
| `make fclean` | `clean` plus `rm -rf /home/abrami/data` — deletes the actual data |
| `make re` | `fclean` then a full rebuild |

## Project description

### Why Docker is used here

Each service is packaged with exactly the dependencies it needs and nothing more. The Dockerfile
is a reproducible build recipe, so the entire infrastructure can be destroyed and rebuilt
identically with one command. The infrastructure is described as files in a git repository
rather than as a sequence of manual steps performed on a server.

### Sources included in the project

| Element | Origin |
|---|---|
| Base OS | `debian:bookworm` — Debian 12, the penultimate stable release (Debian 13 "trixie" being current) |
| NGINX, OpenSSL | Debian `apt` repositories |
| PHP 8.2, php8.2-fpm, php8.2-mysql | Debian `apt` repositories |
| MariaDB server and client | Debian `apt` repositories |
| `wp-cli` | `wp-cli.phar` downloaded from the wp-cli builds branch on GitHub at image build time |
| WordPress core | Downloaded from wordpress.org by `wp core download` at container start |
| TLS certificate | Generated at container start by `openssl req -x509` (self-signed) |

### Main design choices

**1. One service per container, and that service is PID 1.**

Each container has an `ENTRYPOINT` pointing at a shell script. Every script performs its
initialisation and then hands over with `exec`:

* `ssl.sh` ends with `exec nginx -g "daemon off;"`
* `word.sh` ends with `exec php-fpm8.2 -F`
* `mariadb.sh` ends with `exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0`

`exec` replaces the shell process rather than forking a child, so the daemon inherits PID 1.
This matters concretely: `docker stop` sends SIGTERM to PID 1, so the service shuts down cleanly
instead of being killed after the timeout; and if the service dies, the container exits, which
makes the failure visible and lets the restart policy act. Each daemon is also run in the
foreground (`daemon off`, `-F`, no `--daemonize`) because a container has no init system to
supervise a background process.

No `tail -f`, `sleep infinity`, `while true` or bare `bash` is used to keep any container alive.
Those patterns are forbidden by the subject, and they hide failures: the container reports
healthy while the service behind it is dead.

**2. Initialisation is idempotent and guarded.**

Every startup step is wrapped in an existence test, so a second `make` on populated volumes skips
initialisation and starts in seconds:

* `mariadb.sh` runs `mariadb-install-db` only if `/var/lib/mysql/mysql` is absent, and runs the
  database provisioning only if `/var/lib/mysql/$DB_NAME` is absent. The two tests are separate
  on purpose — a datadir can exist without the project's database inside it.
* `word.sh` downloads WordPress only if `wp-load.php` is absent, writes `wp-config.php` only if
  it is absent, and installs only if `wp core is-installed` returns false.
* `ssl.sh` generates the certificate only if `we.crt` is absent.

The MariaDB Dockerfile clears `/var/lib/mysql` after installing the package. The Debian package
initialises a datadir during `apt install`, and Docker copies image content into an empty named
volume on first mount — without clearing it, the guard would see a pre-existing datadir and the
project's own initialisation would never run.

**3. Two-phase MariaDB bootstrap.**

`mariadb-install-db` only writes the system tables. Creating a database, a user and its grants
requires a running server, so `mariadb.sh` starts a temporary `mysqld` in the background, waits
for it to answer, issues the SQL, and shuts it down cleanly. Only then does `exec` launch the
long-running server as PID 1. The background process exists for a few seconds during first boot
only and is not a way of keeping the container alive.

**4. `depends_on` is ordering, not readiness.**

Compose's `depends_on` guarantees start order but says nothing about whether a service is ready
to accept connections. `word.sh` therefore polls with `mysqladmin ping` using the project's
database credentials before running `wp config create`. Authenticating with `$DB_USER` rather
than pinging anonymously means the loop waits for the user to exist, not merely for the server
socket to open.

**5. The WordPress volume is mounted in two containers.**

php-fpm executes the PHP files and NGINX serves the static assets — CSS, JavaScript, images,
uploads — from the same directory. Without the shared mount, every static request would return
404 while PHP pages rendered normally.

**6. No credential is written into any image.**

Passwords reach the containers as environment variables at run time, read from `srcs/.env` by
Compose. Nothing sensitive appears in a Dockerfile, so nothing sensitive is baked into an image
layer where `docker history` would reveal it.

### Virtual Machines vs Docker

| | Virtual machine | Docker container |
|---|---|---|
| What is virtualised | The hardware — a hypervisor emulates CPU, memory and disks | The operating system — namespaces and cgroups isolate processes |
| Kernel | Its own complete guest kernel | Shares the host kernel |
| Footprint | Gigabytes, boots in tens of seconds | Megabytes, starts in milliseconds |
| Isolation | Strong: a compromised guest kernel is still confined to the VM | Weaker: a kernel exploit reaches the host directly |
| Typical use | Running a different operating system, separating tenants | Packaging and shipping one application |

Both are used here, deliberately. The VM provides a disposable, isolated machine to work on;
inside it, Docker provides three lightweight reproducible services. The distinction is the reason
the subject forbids keeping containers alive artificially: a container is not a small machine
that needs to "stay booted", it is a process tree with a private view of the system, and it lives
exactly as long as its main process does.

### Secrets vs Environment Variables

| | Environment variables (`.env`) | Docker secrets |
|---|---|---|
| Storage | Plain-text file on the host, injected into the container environment | Files mounted read-only under `/run/secrets/`, backed by tmpfs |
| Visibility | Readable via `docker inspect`, via `/proc/<pid>/environ`, and often leaked into logs | Not shown by `docker inspect`; readable only inside the container |
| Scope | Inherited by every child process the container spawns | Read explicitly by the code that needs the value |
| Rotation | Requires recreating the container | The backing file can be replaced |

This project uses a git-ignored `srcs/.env` file, which the subject makes mandatory, for both
configuration and credentials. The subject's hard requirement is that no credential reaches the
git repository, which `.gitignore` satisfies — and the check is on history as well as the working
tree, since a password removed in a later commit is still readable in the log.

Docker secrets remain the stronger option and are what the subject recommends. The reason is
visible in the table above: an environment variable is inherited by every child process of the
container, so a password intended for one `mysql` invocation is present in the environment of
everything that runs afterwards, and is exposed to anyone who can call `docker inspect`. A secret
is a file that only the code choosing to read it ever sees.

### Docker Network vs Host Network

| | `network_mode: host` | User-defined bridge (`inception`) |
|---|---|---|
| Network namespace | Shared with the host | Private to the containers |
| Ports | Every container port occupies a host port | Only what is listed under `ports:` is published |
| Service discovery | Everything is `localhost` | Embedded DNS resolves `mariadb` and `wordpress` to container IPs |
| Exposure | MariaDB's 3306 and php-fpm's 9000 would be reachable on the host | Only 443 is reachable |

Host mode and the legacy `--link` are forbidden by the subject. The security model of the project
depends on NGINX being the sole reachable entry point, which host mode would destroy. The
user-defined bridge additionally provides DNS by service name, which is why `word.sh` connects to
the host `mariadb` and `default.conf` forwards to `wordpress:9000` without any address ever being
hardcoded.

### Docker Volumes vs Bind Mounts

| | Bind mount | Named volume |
|---|---|---|
| Declared as | A host path in a service's `volumes:` list | A name in the top-level `volumes:` section |
| Managed by | The user | Docker — visible in `docker volume ls`, removed by `down -v` |
| Portability | Breaks if the host path does not exist | Created by Docker on first use |
| Typical use | Injecting source code during development | Persisting application data |

The project uses named volumes, `mariadb` and `wordpress`, declared in the top-level `volumes:`
section. Because the subject also requires the data to live under `/home/abrami/data`, they are
declared with the `local` driver and a `device` option pointing at that directory:

```yaml
volumes:
  wordpress:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/abrami/data/wordpress
```

The result is still a named volume — Docker creates it, names it `srcs_wordpress`, tracks it and
destroys it on `down -v` — whose backing storage is a directory chosen by the project. Services
reference it by name and never mention a host path, which is what distinguishes it from a bind
mount declared inline in a service.

One consequence is worth knowing: removing the volume with `down -v` removes Docker's volume
object but leaves the contents of `/home/abrami/data` on disk. Clearing the data really does
require deleting that directory, which is what `make fclean` does.

## Resources

**Docker**

* Docker documentation — [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
* Docker documentation — [Compose file reference](https://docs.docker.com/reference/compose-file/)
* Docker documentation — [Volumes](https://docs.docker.com/engine/storage/volumes/) and [Networking](https://docs.docker.com/engine/network/)
* [Docker and the PID 1 zombie reaping problem](https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/)

**Services**

* NGINX — [ngx_http_ssl_module](https://nginx.org/en/docs/http/ngx_http_ssl_module.html) and [ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
* [PHP-FPM configuration reference](https://www.php.net/manual/en/install.fpm.configuration.php)
* [WP-CLI command reference](https://developer.wordpress.org/cli/commands/)
* MariaDB Knowledge Base — [mariadb-install-db](https://mariadb.com/kb/en/mariadb-install-db/)
* [OpenSSL `req`](https://docs.openssl.org/master/man1/openssl-req/)

**Use of AI**

AI was used as an explainer and as a reviewer, not as the author of the project's logic:

* **Understanding concepts** — why `exec` in an entrypoint determines which process becomes PID 1
  and therefore which process receives SIGTERM; how Docker's `local` volume driver behaves with
  the `device` option; the difference between environment variables and mounted secrets.
* **Reviewing the configuration** — a critical read of `docker-compose.yml`, the Dockerfiles and
  the entrypoint scripts against the subject's constraints. This surfaced issues that were then
  reproduced and fixed: the Debian MariaDB package shipping a pre-initialised datadir that
  silently bypassed the project's own initialisation; `wp core install` being given a URL without
  a scheme, which made WordPress emit `http://` redirects on an HTTPS-only site; and the packaged
  `sites-enabled/default` server block listening on port 80 inside the NGINX container.
* **Drafting documentation** — a first structure for this file, `USER_DOC.md` and `DEV_DOC.md`.

Every suggestion was tested on the machine before being kept, and every claim in this
documentation was checked against the files it describes.