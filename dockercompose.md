# Docker Compose File — Complete Guide

A Docker Compose file (commonly named `compose.yaml` or `docker-compose.yml`) defines a multi-container application. It describes the services, networks, and volumes that make up your app, along with their configuration.

This guide covers the **Compose Specification** (used by Docker Compose V2). Legacy version 2/3 files are similar but not identical; notes on differences are included.

---

## Top-Level Keys

| Key          | Purpose |
|--------------|---------|
| `version`    | (Optional/ignored in Compose Spec) Declares the compose file format version. |
| `services`   | Defines the containers (services) that make up your application. **Required**. |
| `networks`   | Defines custom networks that services can attach to. |
| `volumes`    | Defines named volumes that services can mount. |
| `configs`    | Allows services to access non‑sensitive configuration data (Swarm mode). |
| `secrets`    | Allows services to access sensitive data (Swarm mode). |
| `include`    | (Compose Spec only) Allows splitting compose files by including other compose files. |
| `name`       | Sets a custom project name. If omitted, the directory name is used. |

---

## `version` (optional / legacy)

```yaml
version: "3.8"
```

Older Compose files used `version` to enable specific features. In the Compose Specification, it is **optional** and has no effect. You can safely omit it or leave it for compatibility with older tools.

---

## `services`

This is where you define each container. Each service is a named map under `services`.

```yaml
services:
  web:
    # configuration...
  db:
    # configuration...
```

---

### Service Configuration Options

Below are the most important and commonly used keys you can set inside a service.

---

#### 1. `image`

Specifies the image to start the container from. Can be a local image, a public registry image, or a private registry image.

```yaml
image: nginx:latest
image: myregistry.example.com/myapp:1.0
```

If `build` is also specified, Compose will build the image and tag it with the given name.

---

#### 2. `build`

Defines the build context and Dockerfile for building the image. Can be a simple path (string) or a detailed object.

**Simple syntax:**
```yaml
build: ./dir
```

**Full syntax:**
```yaml
build:
  context: ./dir
  dockerfile: Dockerfile.dev
  args:
    APP_VERSION: "1.2.3"
  labels:
    com.example.build: "true"
  cache_from:
    - type=local,src=/tmp/cache
  network: host
  target: builder          # multi-stage build target
```

- `context`: Path to the build context (or a URL). Default is `.`.
- `dockerfile`: Alternate Dockerfile name. Default `Dockerfile`.
- `args`: Build‑time arguments (like `--build-arg`).
- `cache_from`: List of images to use as cache sources.
- `tags`: Additional tags for the built image.
- `platforms`: Target platforms for multi-architecture builds (e.g., `linux/amd64`).

---

#### 3. `container_name`

Sets a custom container name instead of the default `<project>_<service>_<index>`.

```yaml
container_name: my-web-app
```

**Caution:** Container names must be unique. Using this key makes scaling impossible because all instances would share the same name.

---

#### 4. `command`

Overrides the default command declared by the image (i.e., `CMD`).

```yaml
command: ["bundle", "exec", "thin", "-p", "3000"]
# or string form:
command: bundle exec thin -p 3000
```

---

#### 5. `entrypoint`

Overrides the default entrypoint (`ENTRYPOINT`) from the image.

```yaml
entrypoint: ["python", "app.py"]
```

To reset an entrypoint, use an empty array `[]`.

---

#### 6. `environment`

Sets environment variables in the container. Can be a list or a map.

```yaml
environment:
  NODE_ENV: production
  DEBUG: "true"

# or list form (no value = taken from host):
environment:
  - NODE_ENV=production
  - DEBUG
```

---

#### 7. `env_file`

Loads environment variables from one or more files.

```yaml
env_file:
  - ./common.env
  - ./apps/web.env
```

The file should contain lines in the format `VAR=VAL`. Values can optionally be quoted.

---

#### 8. `ports`

Exposes container ports to the host. Format:

```yaml
ports:
  - "HOST_PORT:CONTAINER_PORT/PROTOCOL"
```

Protocol defaults to TCP; use `/udp` for UDP.

```yaml
ports:
  - "3000"                         # bind to random host port
  - "8080:80"                      # host 8080 → container 80
  - "127.0.0.1:8000:80"           # only on loopback
  - "49100-49200:1000-1100"       # port range
```

Long syntax (supports additional options like `mode: host`):
```yaml
ports:
  - target: 80
    host_ip: 127.0.0.1
    published: 8080
    protocol: tcp
    mode: host
```

---

#### 9. `expose`

Exposes ports **without** publishing them to the host machine. They are available to linked services and on the internal network.

```yaml
expose:
  - "3000"
  - "8000"
```

---

#### 10. `volumes`

Mounts host paths or named volumes into the container.

**Short syntax:**
```yaml
volumes:
  - /host/path:/container/path
  - named_volume:/container/path
  - /host/path:/container/path:ro   # read-only
```

**Long syntax:**
```yaml
volumes:
  - type: bind
    source: ./static
    target: /usr/share/nginx/html
    read_only: true
  - type: volume
    source: myvol
    target: /data
    volume:
      nocopy: true   # prevents copying existing container data into volume
```

---

#### 11. `networks`

Joins the service to networks defined in the top‑level `networks` section. Can be a simple list or a map with options.

```yaml
networks:
  - frontend
  - backend

# with options:
networks:
  frontend:
    aliases:
      - web
  backend:
    ipv4_address: 172.16.238.10
```

Options include `aliases`, `ipv4_address`, `ipv6_address`, `priority`, etc.

---

#### 12. `depends_on`

Controls the order of service startup and shutdown.

```yaml
depends_on:
  - db
  - redis
```

**Long syntax** (Compose Spec V2) adds condition, restart, and required options:

```yaml
depends_on:
  db:
    condition: service_healthy   # service_started (default), service_healthy, service_completed_successfully
    restart: true
    required: true
```

⚠️ `depends_on` only waits for the container to start, not for the application inside to be ready. Use healthchecks or external scripts for readiness.

---

#### 13. `healthcheck`

Defines a check to determine if the container is “healthy”. Overrides any `HEALTHCHECK` from the Dockerfile.

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/"]
  interval: 1m30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

Disable inherited healthcheck:
```yaml
healthcheck:
  disable: true
```

---

#### 14. `restart`

Defines the restart policy for the container.

```yaml
restart: unless-stopped
```

Options: `no` (default), `always`, `on-failure`, `unless-stopped`.

---

#### 15. `logging`

Configures logging driver and options.

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

---

#### 16. `extra_hosts`

Adds hostname mappings to `/etc/hosts` inside the container.

```yaml
extra_hosts:
  - "somehost:162.242.195.82"
  - "otherhost:50.31.209.229"
```

---

#### 17. `dns`, `dns_search`, `dns_opt`

Custom DNS configuration.

```yaml
dns:
  - 8.8.8.8
  - 1.1.1.1
dns_search: example.com
dns_opt:
  - use-vc
  - no-tld-query
```

---

#### 18. `user`

Sets the user (and group) that runs the container.

```yaml
user: "1000:1000"
user: appuser
```

---

#### 19. `working_dir`

Overrides the working directory for the container.

```yaml
working_dir: /app
```

---

#### 20. `secrets`

Grants access to sensitive data defined at the top level (Swarm mode, but works with Compose when using `--secrets` or file mounts).

```yaml
secrets:
  - db_password
  - source: api_key
    target: /run/secrets/custom_path
```

---

#### 21. `configs`

Like `secrets` but for non‑sensitive configuration files (mostly Swarm).

```yaml
configs:
  - source: my_config
    target: /etc/my_config.conf
    uid: "103"
    gid: "103"
    mode: 0440
```

---

#### 22. `profiles`

Marks the service for optional activation via the `--profile` flag.

```yaml
services:
  debug:
    image: debug-tools
    profiles:
      - debug
```
Start with: `docker compose --profile debug up`.

---

#### 23. `deploy`

Specifies deployment and resource constraints. **Only effective when deploying to Swarm** (except `resources` which also work with Docker Compose V2).

```yaml
deploy:
  mode: replicated
  replicas: 2
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
  restart_policy:
    condition: on-failure
    delay: 5s
    max_attempts: 3
    window: 120s
  placement:
    constraints:
      - node.role == manager
```

---

#### 24. `cap_add`, `cap_drop`

Add or drop Linux capabilities.

```yaml
cap_add:
  - ALL
cap_drop:
  - NET_ADMIN
  - SYS_ADMIN
```

---

#### 25. `security_opt`

Override default labeling and security options.

```yaml
security_opt:
  - label:user:USER
  - no-new-privileges:true
```

---

#### 26. `tmpfs`

Mounts a temporary file system inside the container.

```yaml
tmpfs:
  - /run
  - /tmp:size=64M,uid=1000
```

---

#### 27. `stop_signal`

Sets the signal used to stop the container.

```yaml
stop_signal: SIGINT
```

---

#### 28. `stop_grace_period`

Time to wait after sending the stop signal before force‑killing the container.

```yaml
stop_grace_period: 10s
```

---

#### 29. `init`

Runs an init process inside the container to forward signals and reap zombie processes.

```yaml
init: true
```

---

#### 30. `external_links`

Links to containers started outside this Compose project (deprecated, prefer networks).

```yaml
external_links:
  - redis_1
  - project_db_1:mysql
```

---

#### 31. `labels`, `network_mode`, `pid`, `sysctls`, `devices`, etc.

Additional advanced configuration:

- `labels`: Add metadata to the container.
- `network_mode`: Set to `host`, `none`, `service:<name>` or `container:<id>`.
- `pid`: `host` to share host PID namespace.
- `sysctls`: Kernel parameters.
- `devices`: List of host devices to map.

```yaml
network_mode: host
pid: "host"
sysctls:
  net.core.somaxconn: 1024
devices:
  - "/dev/ttyUSB0:/dev/ttyUSB0"
```

---

## `networks` (top level)

Defines custom networks that services can join.

```yaml
networks:
  frontend:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: br_frontend
    ipam:
      config:
        - subnet: 10.0.1.0/24
  backend:
    driver: overlay
    attachable: true
```

Common drivers: `bridge`, `host`, `overlay` (Swarm), `none`.  
`external: true` can be used to refer to an already existing network.

---

## `volumes` (top level)

Defines named volumes that can be used by services.

```yaml
volumes:
  db_data:
    driver: local
    driver_opts:
      type: none
      device: /mnt/data
      o: bind
  shared_data:
    external: true   # uses an already existing volume
```

---

## `configs` and `secrets` (top level)

Allow injecting files into containers without rebuilding. Commonly used in Swarm, but `secrets` can be emulated in Compose by mounting a file.

```yaml
secrets:
  db_password:
    file: ./db_password.txt

configs:
  nginx_config:
    file: ./nginx.conf
```

---

## `include` (Compose Specification)

Allows merging multiple Compose files into one project. Useful for splitting large configurations.

```yaml
include:
  - path: ./services/web.yaml
    project_directory: .
    env_file: ./prod.env
  - path: ../commons/db.yaml
```

---

## `name`

Sets the project name explicitly.

```yaml
name: myproject
```

If omitted, the project name is derived from the directory name or the `--project-name` flag.

---

## YAML Anchors & Extensions

Compose supports YAML features like anchors (`&`), aliases (`*`), and merge keys (`<<`) to reduce repetition.

```yaml
x-logging: &default-logging
  driver: json-file
  options:
    max-size: "10m"

services:
  web:
    logging: *default-logging
  db:
    logging:
      <<: *default-logging
      options:
        max-size: "20m"    # override
```

---

## Quick Comparison: Dockerfile vs Compose

| Feature        | Dockerfile                        | Compose                                 |
|----------------|-----------------------------------|-----------------------------------------|
| Purpose        | Build a single image.             | Define and run multi‑container apps.    |
| Key commands   | `FROM`, `RUN`, `COPY`, `CMD`…     | `services`, `networks`, `volumes`…      |
| Networking     | No built‑in networking.           | Automatic isolated network per project. |
| Scaling        | Manual with `docker run`.         | `docker compose up --scale web=3`.      |
| Environment    | `ENV` / `ARG` at build time.      | Runtime env via `environment` / `.env`. |

---

This guide covers all major Compose file directives. Refer to the [official Compose Specification](https://docs.docker.com/compose/compose-file/) for the most up‑to‑date and detailed reference.