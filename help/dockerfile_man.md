# Dockerfile Instructions — Complete Guide

A Dockerfile is a text document containing a series of instructions that Docker uses to build an image.  
Below is an explanation of all the standard instructions, with syntax, purpose, and examples.

---

## 1. FROM

```dockerfile
FROM <image>[:<tag>] [AS <name>]
```

**Purpose:** Sets the base image for subsequent instructions. Every valid Dockerfile must start with a `FROM` (except when using `ARG` before the first `FROM` for dynamic base images).  
`AS <name>` is optional and gives a name to the build stage in multi‑stage builds.

**Example:**
```dockerfile
FROM ubuntu:22.04 AS builder
```

---

## 2. RUN

```dockerfile
RUN <command>                                  # shell form
RUN ["executable", "param1", "param2"]         # exec form
```

**Purpose:** Executes a command in a new layer on top of the current image and commits the result. Used for installing packages, creating files, etc.  
- **Shell form** runs in `/bin/sh -c` on Linux (or `cmd /S /C` on Windows).  
- **Exec form** does not invoke a shell; use it to avoid shell processing.

**Example:**
```dockerfile
RUN apt-get update && apt-get install -y curl
RUN ["apt-get", "update"]
```

**Best practice:** Chain commands with `&&` and clean up in the same `RUN` to reduce layer size.

---

## 3. CMD

```dockerfile
CMD ["executable","param1","param2"]   # exec form (preferred)
CMD ["param1","param2"]                # as default arguments to ENTRYPOINT
CMD command param1 param2              # shell form
```

**Purpose:** Provides defaults for an executing container. There can only be **one** `CMD` instruction in a Dockerfile; if multiple exist, only the last one takes effect.  
When the container is run without a command, the `CMD` instruction is executed. If a command is supplied (`docker run <image> <command>`), the `CMD` defaults are overridden.

**Example:**
```dockerfile
CMD ["python", "app.py"]
```

**Note:** If combined with `ENTRYPOINT`, `CMD` supplies default arguments to the entrypoint.

---

## 4. LABEL

```dockerfile
LABEL <key>=<value> <key>=<value> ...
```

**Purpose:** Adds metadata to the image (e.g., maintainer, version, description). Labels can be inspected with `docker inspect`.

**Example:**
```dockerfile
LABEL maintainer="user@example.com" version="1.0" description="My app"
```

---

## 5. MAINTAINER (deprecated)

```dockerfile
MAINTAINER <name>
```

**Purpose:** Sets the author field of the image. Deprecated in favour of `LABEL`.  
**Example (avoid):**
```dockerfile
MAINTAINER John Doe <john@example.com>
```
**Use instead:**
```dockerfile
LABEL maintainer="John Doe <john@example.com>"
```

---

## 6. EXPOSE

```dockerfile
EXPOSE <port> [<port>/<protocol>...]
```

**Purpose:** Informs Docker that the container listens on the specified network port(s) at runtime.  
`EXPOSE` does **not** publish the port; it is used for inter‑container communication (e.g., with `--link`) and as a hint.  
Default protocol is TCP; use `udp` for UDP.

**Example:**
```dockerfile
EXPOSE 80/tcp
EXPOSE 8080
```

---

## 7. ENV

```dockerfile
ENV <key> <value>           # sets one variable
ENV <key>=<value> ...       # allows multiple variables at once
```

**Purpose:** Sets environment variables that persist when a container is run. They can be used in subsequent instructions (e.g., `RUN`, `ADD`, `COPY`).

**Example:**
```dockerfile
ENV NODE_ENV=production
ENV PATH="/usr/local/app/bin:$PATH"
```

**Note:** The first form (`ENV key value`) only allows a single key; the `=` form can set multiple keys at once.

---

## 8. ADD

```dockerfile
ADD [--chown=<user>:<group>] <src>... <dest>
ADD [--chown=<user>:<group>] ["<src>",... "<dest>"]  # for paths with spaces
```

**Purpose:** Copies new files, directories, or remote file URLs from `<src>` and adds them to the image’s filesystem at `<dest>`.  
Special features:
- If `<src>` is a local **tar** archive, it is automatically extracted.
- `<src>` may be a URL (downloads the file).

**Example:**
```dockerfile
ADD --chown=node:node files/ /app/
ADD https://example.com/file.txt /tmp/
```

**Recommendation:** Prefer `COPY` unless you specifically need the tar auto‑extraction or URL download feature.

---

## 9. COPY

```dockerfile
COPY [--chown=<user>:<group>] <src>... <dest>
COPY [--chown=<user>:<group>] ["<src>",... "<dest>"]
```

**Purpose:** Copies files and directories from the build context (or a previous stage) into the image.  
Unlike `ADD`, it does **not** support URL sources or automatic tar extraction.

**Example:**
```dockerfile
COPY --chown=1000:1000 package.json /app/
COPY . /app
```

**Best practice:** Use `COPY` for simple file copying; it is more transparent.

---

## 10. ENTRYPOINT

```dockerfile
ENTRYPOINT ["executable", "param1", "param2"]  # exec form (preferred)
ENTRYPOINT command param1 param2               # shell form
```

**Purpose:** Configures a container to run as an executable.  
The `ENTRYPOINT` instruction and any `CMD` arguments (or command‑line arguments) are combined:  
- If `CMD` is defined, its arguments are appended to the entrypoint.  
- Arguments passed with `docker run <image> <args>` **override** the `CMD` arguments but **not** the entrypoint (unless `--entrypoint` is used).

**Example:**
```dockerfile
ENTRYPOINT ["python", "app.py"]
CMD ["--help"]   # default argument
```
Running `docker run myimage --version` results in `python app.py --version`.

**Best practice:** Use the **exec form** to ensure proper signal handling. The shell form starts a shell that runs the command, which may not receive Unix signals correctly.

---

## 11. VOLUME

```dockerfile
VOLUME ["/data"]
VOLUME /path1 /path2 ...
```

**Purpose:** Creates a mount point with the specified name and marks it as holding externally mounted volumes from the host or other containers.  
A `VOLUME` instruction **cannot** specify a host directory; the actual location is managed by Docker. Useful for databases, logs, etc.

**Example:**
```dockerfile
VOLUME /var/log
VOLUME ["/data", "/config"]
```

---

## 12. USER

```dockerfile
USER <user>[:<group>]
USER <UID>[:<GID>]
```

**Purpose:** Sets the user name (or UID) and optionally the group (or GID) to use when running the image and for any `RUN`, `CMD`, and `ENTRYPOINT` instructions that follow.

**Example:**
```dockerfile
USER appuser
USER 1000:1000
```

**Note:** Ensure the user exists in the image (e.g., created earlier with `RUN adduser`).

---

## 13. WORKDIR

```dockerfile
WORKDIR /path/to/directory
```

**Purpose:** Sets the working directory for subsequent `RUN`, `CMD`, `ENTRYPOINT`, `COPY`, and `ADD` instructions. If the directory does not exist, it is created.  
Can be used multiple times; relative paths are resolved relative to the previous `WORKDIR`.

**Example:**
```dockerfile
WORKDIR /app
RUN pwd   # /app
WORKDIR sub
RUN pwd   # /app/sub
```

---

## 14. ARG

```dockerfile
ARG <name>[=<default value>]
```

**Purpose:** Defines a build‑time variable that users can pass with `--build-arg <name>=<value>` during `docker build`.  
`ARG` variables are not persisted in the final image (except if they are used by `ENV`). They can be used in subsequent instructions.

**Example:**
```dockerfile
ARG VERSION=latest
FROM ubuntu:${VERSION}
ARG BUILD_DATE   # no default
RUN echo "Build date: $BUILD_DATE"
```

**Important:** An `ARG` declared before the first `FROM` is outside any build stage and can only be used in `FROM` lines.

---

## 15. ONBUILD

```dockerfile
ONBUILD <INSTRUCTION>
```

**Purpose:** Adds a trigger to the image that will be executed later, when the image is used as the base for another build.  
The `<INSTRUCTION>` is not executed during the current build but is registered and run immediately after the `FROM` in the child Dockerfile.

**Example:**
```dockerfile
ONBUILD COPY . /app/src
ONBUILD RUN /usr/local/bin/python-build --dir /app/src
```

**Use case:** Useful for base images that enforce a common build step in derived images (e.g., a language runtime image that automatically copies source code).

**Caution:** The trigger is inherited by further descendants; use only when the behaviour is clearly documented.

---

## 16. STOPSIGNAL

```dockerfile
STOPSIGNAL signal
```

**Purpose:** Sets the system call signal that will be sent to the container to stop it.  
Signal can be a signal name (e.g., `SIGKILL`) or an unsigned number (e.g., `9`).

**Example:**
```dockerfile
STOPSIGNAL SIGTERM
```

---

## 17. HEALTHCHECK

```dockerfile
HEALTHCHECK [OPTIONS] CMD <command>         # check container health
HEALTHCHECK NONE                            # disable any inherited healthcheck
```

**Purpose:** Tells Docker how to test a container to check that it is still working.  
Options:
- `--interval=DURATION` (default 30s)
- `--timeout=DURATION` (default 30s)
- `--retries=N` (default 3)
- `--start-period=DURATION` (default 0s)

**Example:**
```dockerfile
HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://localhost/ || exit 1
```

---

## 18. SHELL

```dockerfile
SHELL ["executable", "parameters"]
```

**Purpose:** Changes the default shell used for the **shell form** of commands (`RUN`, `CMD`, `ENTRYPOINT`).  
Default on Linux is `["/bin/sh", "-c"]`, on Windows `["cmd", "/S", "/C"]`.

**Example:**
```dockerfile
SHELL ["/bin/bash", "-c"]
RUN echo "Using bash now"
```

---

## Special: Parser Directives

Though not instructions, parser directives can appear at the very top of a Dockerfile:

- **`# syntax=docker/dockerfile:1`** – enables BuildKit syntax.
- **`# escape=\`** – changes the escape character from `\` to `` ` `` (useful on Windows).

**Example:**
```dockerfile
# escape=`
FROM microsoft/nanoserver
COPY testfile.txt c:\
```

---

## Quick Reference: CMD vs ENTRYPOINT

| Feature                      | CMD                         | ENTRYPOINT                 |
|------------------------------|-----------------------------|----------------------------|
| Overridable by `docker run` arguments? | Yes, fully replaced.       | No, arguments are appended; only `--entrypoint` overrides it. |
| Typical use                  | Default command or parameters | Container acts as an executable |
| Combines with…               | ENTRYPOINT to provide default args | CMD to provide default args |

**Example together:**
```dockerfile
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
```
Running `docker run myimage` → `docker-entrypoint.sh postgres`  
Running `docker run myimage -d` → `docker-entrypoint.sh -d`

---

This guide covers all current Dockerfile instructions. Use them wisely to create efficient, secure, and maintainable images.