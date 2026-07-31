*This project has been created as part of the 42 curriculum by alijr2018.*

## Description
This repository contains the mandatory Inception infrastructure built with Docker Compose. The stack runs three dedicated services: MariaDB, WordPress with PHP-FPM, and NGINX with TLS on port 443. Data persistence is handled with named volumes mapped under `/home/<login>/data`.

## Instructions
1. Copy `/home/runner/work/inception/inception/srcs/.env.example` to `/home/runner/work/inception/inception/srcs/.env`.
2. Set your own values in `.env` (especially `LOGIN`, `DOMAIN_NAME`, and passwords).
3. Ensure host directories exist:
   - `/home/<login>/data/mariadb`
   - `/home/<login>/data/wordpress`
4. Add your domain to `/etc/hosts`:
   - `127.0.0.1 <login>.42.fr`
5. Run from repository root:
   - `make`
6. Open `https://<login>.42.fr`.

## Project description
### Why Docker in this project
Docker packages each service with its dependencies and runtime configuration, making the full infrastructure reproducible and isolated.

### Source layout
- `Makefile`: lifecycle commands (`up`, `down`, `clean`, `re`, etc.)
- `srcs/docker-compose.yml`: service orchestration
- `srcs/requirements/mariadb`: MariaDB image and init script
- `srcs/requirements/wordpress`: WordPress + PHP-FPM image and setup script
- `srcs/requirements/nginx`: NGINX + TLS image and startup script

### Main design choices
- One container per service.
- Custom Dockerfiles from Debian Bullseye (no prebuilt service images).
- NGINX is the single external entrypoint on port 443.
- Shared WordPress volume between NGINX and WordPress.
- Database and website data persisted using named volumes under `/home/<login>/data`.

### Comparisons
#### Virtual Machines vs Docker
A VM virtualizes full hardware and includes a full guest OS; Docker shares the host kernel and runs isolated processes with lower overhead and faster startup.

#### Secrets vs Environment Variables
Environment variables are simple and required in this project, but they are not ideal for sensitive values in long-term production. Secrets are better for confidential data because they reduce accidental exposure.

#### Docker Network vs Host Network
A Docker bridge network isolates containers and gives service discovery by name. Host networking removes this isolation and is forbidden in this project.

#### Docker Volumes vs Bind Mounts
Named volumes are Docker-managed and portable across hosts. Bind mounts directly expose host paths. This project uses named volumes (with local driver options) as required by the subject.

## Resources
- Docker Compose specification: https://docs.docker.com/compose/compose-file/
- Dockerfile reference: https://docs.docker.com/reference/dockerfile/
- NGINX FastCGI docs: https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
- WP-CLI docs: https://developer.wordpress.org/cli/commands/
- MariaDB docs: https://mariadb.com/kb/en/documentation/

### AI usage
AI was used to review compliance against the subject, identify configuration gaps, and structure documentation. All resulting configuration/scripts were manually reviewed for correctness.
