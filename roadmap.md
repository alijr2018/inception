# Inception – One‑Week Roadmap with Research Prompts (Mandatory Part)

> This roadmap tells you **what to do** and **what to search for** each day.  
> Look up every term you don’t know yet — the project is as much about understanding as it is about getting it running.

---

## Day 1 – Environment & Core Concepts

**Goals:** Set up the virtual machine, install Docker, create project skeleton, learn the fundamentals.

### Tasks
- Install Docker Engine + Docker Compose plugin on a Debian/Ubuntu VM.
- Create the required directory structure (see subject).
- Initialize a Git repo, add `.gitignore` for `.env` and `secrets/`.
- Decide on base image: **Alpine 3.18** or **Debian 11 (bullseye)**.
- Draft a preliminary `.env` file.

### What to search / learn
- **Docker overview**: “What is a Docker image vs container”, “Docker architecture diagram”
- **Docker Compose basics**: “docker-compose.yml structure”, “services, volumes, networks in compose”
- **Dockerfile fundamentals**: “Dockerfile instructions FROM, RUN, COPY, ENTRYPOINT, CMD”, “multi-stage builds (just to know they exist)”
- **Docker volumes**: “Docker named volumes vs bind mounts”, “Docker volume driver options”, “how to store named volume data on a specific host path”
- **Docker networks**: “Docker bridge network”, “how containers communicate by service name”
- **Process management in containers**: “PID 1 in Docker”, “why you should not use tail -f as main process”, “best practices for Docker CMD/ENTRYPOINT”
- **Alpine vs Debian**: “Alpine Linux for Docker pros cons”, “Debian slim images”, “penultimate stable version Debian/Alpine”
- **Environment variables in Docker**: “env_file vs environment in docker-compose”, “build args vs runtime env”
- **Git setup**: “git init”, “.gitignore syntax”

---

## Day 2 – MariaDB Service

**Goals:** Build a MariaDB container that initializes the WordPress database and user, and stores data persistently.

### Tasks
- Write `Dockerfile` for MariaDB.
- Create a minimal `my.cnf` (MariaDB/MySQL config).
- Write an init script that:
  - Detects if the database is already initialized.
  - If not, creates the database and users using environment variables.
  - Ends with `exec mysqld` (or `mariadbd`).
- Add the service to `docker-compose.yml` with:
  - A named volume for data (placed under `/home/<login>/data/mariadb`).
  - The restart policy `always`.
  - The service attached to your custom network.
- Test: start only MariaDB, connect manually, run `SHOW DATABASES;`

### What to search / learn
- **MariaDB in Docker**: “mariadb official image Dockerfile” (just to learn structure, not to copy), “mariadb first time initialization script”
- **MySQL/MariaDB user management**: “CREATE USER, GRANT ALL PRIVILEGES syntax”, “ALTER USER to set root password”
- **Entrypoint scripts**: “Docker entrypoint script best practices”, “how to use exec in shell scripts”, “bash conditional file existence test”
- **Volume configuration**: “docker volume create with driver options”, “how to force a named volume to use a specific host path” (search “docker volume local driver options device”)
- **Daemon management**: “mysqld foreground mode”, “why mariadbd needs to be PID 1”
- **No passwords in Dockerfile**: “passing secrets to Docker build vs runtime”, “env_file vs docker secrets”

---

## Day 3 – WordPress + PHP‑FPM

**Goals:** Container running PHP-FPM and WordPress, connected to MariaDB, with persistent website files.

### Tasks
- Write `Dockerfile` for WordPress:
  - Install `php-fpm`, `php-mysql`, and `wp-cli`.
  - Configure PHP-FPM to listen on port 9000 (over TCP or socket? subject implies TCP).
- Create a setup script that:
  - Checks if `wp-config.php` exists.
  - Uses `wp-cli` to download core, create config, install WordPress, and create two users.
  - Starts PHP-FPM as PID 1 (`php-fpm -F` or similar).
- Add service to `docker-compose`:
  - Named volume for `/var/www/html` (placed under `/home/<login>/data/wp_files`).
  - Depends on MariaDB.
- Test: launch both services, check logs that WordPress was installed, files appear in volume.

### What to search / learn
- **PHP-FPM**: “php-fpm pool configuration www.conf”, “listen = 9000”, “php-fpm foreground mode”, “php-fpm user/group www-data”
- **WordPress CLI (wp-cli)**: “wp core download”, “wp config create”, “wp core install”, “wp user create”, “how to pass database credentials”
- **PHP MySQL extension**: “php-mysql package name on Debian/Alpine”
- **WordPress file structure**: “what is wp-config.php”, “where are WordPress files stored”
- **Persistent volumes**: “wordpress files volume docker”, “why you need a volume for /var/www/html”
- **Testing PHP-FPM without a web server**: “how to check if php-fpm is running”, “ps aux inside container”
- **WordPress admin user naming**: “wordpress admin username restrictions”, “why admin is not allowed”

---

## Day 4 – NGINX with TLS

**Goals:** NGINX container as the only entry point, HTTPS on port 443, proxy to WordPress.

### Tasks
- Write `Dockerfile` for NGINX:
  - Install `nginx` and `openssl`.
  - Generate a self-signed certificate (using domain from build arg).
  - Copy an NGINX config template that uses `$DOMAIN_NAME` variable.
  - Create a start script that runs `envsubst` on the template and then `exec nginx -g "daemon off;"`.
- NGINX configuration:
  - Listen 443 ssl.
  - SSL certificate and key paths.
  - Restrict protocols to TLSv1.2 and TLSv1.3.
  - Root directory pointing to WordPress files (same volume).
  - FastCGI pass to `wordpress:9000`.
- Add service to `docker-compose`:
  - Publish port 443.
  - Mount the WordPress volume (same named volume!).
  - Depends on WordPress.
- Add domain to `/etc/hosts`: `127.0.0.1 <login>.42.fr`.
- Test: `curl -k https://<login>.42.fr` and browser access (ignore cert warning).

### What to search / learn
- **NGINX as reverse proxy**: “nginx reverse proxy fastcgi php”, “fastcgi_pass directive”, “fastcgi_param SCRIPT_FILENAME”
- **TLS/SSL**: “what is TLSv1.2 vs TLSv1.3”, “nginx ssl_protocols directive”, “how to generate self-signed certificate with openssl”, “openssl req -x509 -nodes”
- **Build arguments**: “docker build --build-arg”, “using ARG in Dockerfile”, “passing DOMAIN_NAME to image”
- **envsubst**: “envsubst command”, “template config files with envsubst”
- **Daemon off**: “nginx daemon off; meaning”, “why nginx must run in foreground in Docker”
- **Testing TLS**: “openssl s_client -connect”, “verify TLS version with openssl”, “curl -k insecure”
- **Port mapping**: “docker ports 443:443”, “difference between expose and ports”
- **Volume sharing between containers**: “shared volume in docker-compose”, “multiple services using same named volume”

---

## Day 5 – Secrets, .env, Makefile & Security Polish

**Goals:** Harden credentials, write the Makefile, verify every rule.

### Tasks
- Move all passwords to Docker secrets (using Docker Swarm) or to files in `secrets/`.
- Keep non-sensitive vars (domain, database name) in `.env`.
- Write a `Makefile` with `up`, `down`, `clean`, `re` targets.
- Verify each project rule:
  - No `latest` tag.
  - No passwords in Dockerfiles.
  - Containers restart on crash.
  - No forbidden network modes (`host`, `links`).
  - No infinite loops in entrypoints (everything ends with `exec`).
  - Named volumes point to `/home/<login>/data/...`.
  - Domain resolution works.

### What to search / learn
- **Docker secrets**: “docker swarm secrets”, “docker compose secrets example”, “how to mount secrets in container”, “docker secret create from file”, “reading secrets in entrypoint script”
- **Makefile basics**: “Makefile targets phony”, “docker compose commands in Makefile”, “variables in Makefile”
- **Docker build tags**: “why latest tag is bad”, “docker image tag best practices”, “penultimate stable alpine version”
- **Security audit**: “how to check docker image for passwords”, “docker history to see layers”, “removing sensitive data from git history”
- **Docker restart policies**: “restart: always vs unless-stopped”, “docker container auto-restart”
- **Process supervision**: “PID 1 problem”, “why tail -f is hacky”, “signal propagation in docker”, “docker stop SIGTERM”

---

## Day 6 – Integration Testing & Peer Review

**Goals:** End-to-end testing and explaining everything.

### Tasks
- Run `make clean && make` from scratch.
- Test:
  - HTTPS access.
  - WordPress admin login.
  - Second user login.
  - Data persistence after restart.
  - Container crash recovery.
  - TLS version enforcement (old protocols rejected).
- Simulate peer review: explain every Dockerfile, compose file, scripts, and design choices.

### What to search / learn
- **Debugging Docker**: “docker logs”, “docker exec -it”, “docker inspect”, “docker volume inspect”, “docker network inspect”
- **Testing persistence**: “docker compose down and up data persistence”, “named volumes survive container removal”
- **Crash recovery test**: “docker kill”, “docker ps restarting”
- **TLS verification commands**: “openssl s_client -tls1_2”, “openssl s_client -no_tls1_2”, “test TLS version script”
- **Peer review preparation**: “common Inception project questions”, “explain Docker networking”, “how does envsubst work”, “difference between ENTRYPOINT and CMD”, “why exec is used”
- **WordPress check**: “how to verify WordPress users”, “wp user list”

---

## Day 7 – Refinement & Bonus Prep

**Goals:** Polish code, write documentation, optionally start bonus.

### Tasks
- Clean up comments, remove any dead code.
- Write a `README.md` describing architecture, how to run, and key decisions.
- Re-test from a completely fresh environment (destroy VM if possible).
- If time, research and add one bonus service (Redis, Adminer, etc.).

### What to search / learn
- **Documentation**: “how to write a good README for a docker project”, “markdown syntax”
- **Bonus ideas**: “redis cache for wordpress docker”, “adminer docker container”, “docker compose service dependencies”
- **Extra security**: “docker image vulnerability scanning”, “trivy docker scan”
- **Clean slate test**: “how to completely remove docker images containers volumes”, “docker system prune -a --volumes”
- **Project submission**: “tagging release in git”, “git tag -a v1.0”

---

> **Pro tip:** Whenever you encounter an error, search it **literally** – Docker and Linux errors are extremely well documented.  
> Use the 42 AI Guidelines: AI can speed you up, but **you must understand everything you commit**.  
> Good luck!