# Containerfile & Dockerfile Reference Guide

This comprehensive guide breaks down the core instructions used to build container images, complete with detailed explanations, professional use cases, and concrete examples.

---

## 1. Core Build Instructions

### FROM
**Sets the base image for subsequent instructions.** It serves as the foundation of your container. Every valid Containerfile must start with a `FROM` instruction (with a few exceptions like `ARG` before it).

* **Syntax:** `FROM <image>[:tag]` or `FROM <image>[@digest]`
* **Best Practice:** Always specify a specific version tag (e.g., `ubuntu:22.04` or `node:20-alpine`) instead of `latest` to ensure your builds are reproducible.

```dockerfile
# Example: Using an explicit, lightweight Alpine base image for Node.js
FROM node:20-alpine
```

### RUN
**Executes commands in a new layer during the build process.** It is primarily used to install packages, modify system configurations, or run scripts needed to set up the application environment.

* **Syntax (Shell form):** `RUN <command>`
* **Syntax (Exec form):** `RUN ["executable", "param1", "param2"]`
* **Best Practice:** Combine related commands using `&&` and clean up package caches in the same layer to keep the final image size minimal.

```dockerfile
# Example: Installing packages and cleaning up the cache in a single layer
RUN apt-get update && apt-get install -y \
    curl \
    git \
 && rm -rf /var/lib/apt/lists/*
```

---

## 2. File and Context Operations

### COPY
**Copies local files and directories from your host machine into the container filesystem.** It transfers items directly without extra processing.

* **Syntax:** `COPY <src> <dest>`
* **Best Practice:** Use `COPY` instead of `ADD` for standard file transfers, as its behavior is predictable and explicit.

```dockerfile
# Example: Copying package files first to leverage build cache optimization
COPY package.json package-lock.json ./
```

### ADD
**Copies files, unpacks tarballs, or fetches remote URLs into the container.** While similar to `COPY`, it features additional automated features like archive extraction.

* **Syntax:** `ADD <src> <dest>`
* **Best Practice:** Only use `ADD` when you specifically need to extract a local tarball directly into the container (e.g., `tar -x`). For fetching remote files, prefer using `RUN curl` or `RUN wget` because it avoids creating unnecessary layers if the file needs to be cleaned up.

```dockerfile
# Example: Automatically unpacking a local compressed archive into a folder
ADD source-code.tar.gz /usr/src/app/
```

### WORKDIR
**Sets the working directory for any subsequent instructions.** Commands like `RUN`, `CMD`, `ENTRYPOINT`, `COPY`, and `ADD` will all execute relative to this path.

* **Syntax:** `WORKDIR /path`
* **Best Practice:** Use absolute paths for `WORKDIR`. If the directory does not exist, it will be automatically created.

```dockerfile
# Example: Setting an explicit, absolute application directory
WORKDIR /usr/src/app
```

---

## 3. Configuration and Variables

### ENV
**Sets environment variables that persist both during the build and when the container runs.** These variables are accessible by the application at runtime.

* **Syntax:** `ENV <key>=<value>` or `ENV <key> <value>`
* **Best Practice:** Avoid using `ENV` for sensitive secrets (like passwords or API keys), as they remain visible to anyone inspecting the image layers via `docker inspect`.

```dockerfile
# Example: Configuring a production flag for a Node/Python app
ENV NODE_ENV=production
ENV PORT=8080
```

### ARG
**Defines build-time variables that users can pass during the build process.** Unlike `ENV`, `ARG` variables do not persist inside the final running container image.

* **Syntax:** `ARG <name>[=<default value>]`
* **Usage:** Pass values using the `--build-arg <name>=<value>` flag during deployment.

```dockerfile
# Example: Declaring an application version argument with a default value
ARG APP_VERSION=1.0.0
RUN echo "Building version ${APP_VERSION}"
```

---

## 4. Networking and Storage

### EXPOSE
**Documents the ports on which the container listens at runtime.** This instruction serves as documentation between the image builder and the container operator; it does not actually publish the port to the host machine.

* **Syntax:** `EXPOSE <port>[/<protocol>]`

```dockerfile
# Example: Documenting that the app inside listens on port 8080 over TCP
EXPOSE 8080/tcp
```

### VOLUME
**Creates a mount point for persisting data.** It marks a directory as an externally managed volume, preventing its contents from being written to the temporary container layer.

* **Syntax:** `VOLUME ["/path/to/directory"]`
* **Best Practice:** Use volumes for databases, log directories, or user uploads to prevent data loss when a container is updated or recreated.

```dockerfile
# Example: Setting up a persistent data directory for a database
VOLUME ["/var/lib/mysql"]
```

---

## 5. Execution and Security

### USER
**Sets the username or UID to use when running the image.** It applies to the remaining build steps and acts as the default user for the running container.

* **Syntax:** `USER <user>[:<group>]` or `USER <UID>[:<GID>]`
* **Best Practice:** Never run your application as the root user in production. Always switch to a non-privileged user to limit security vulnerabilities.

```dockerfile
# Example: Switching away from root to a safe, built-in non-root user
USER node
```

### CMD
**Sets the default command to run when the container starts.** If the user specifies a command when running the container (e.g., `docker run my-image echo "hello"`), the `CMD` instruction is completely overridden.

* **Syntax (Exec Form):** `CMD ["executable", "param1"]`
* **Syntax (Shell Form):** `CMD command param1`

```dockerfile
# Example: Providing the default start command for a web server
CMD ["npm", "start"]
```

### ENTRYPOINT
**Configures a container to run as an executable.** Unlike `CMD`, arguments passed at runtime are appended to the `ENTRYPOINT` command rather than overriding it entirely.

* **Syntax (Exec Form):** `ENTRYPOINT ["executable", "param1"]`

```dockerfile
# Example: Forcing the container to run a specific binary, using CMD for arguments
ENTRYPOINT ["/usr/bin/git"]
CMD ["--help"]
```

---

## 6. Complete Production Example

Here is how all these instructions fit together into a production-ready Containerfile:

```dockerfile
# 1. Base Image
FROM node:20-alpine

# 2. Build Argument
ARG BUILD_ENV=production

# 3. Working Directory
WORKDIR /app

# 4. Environment Variables
ENV NODE_ENV=${BUILD_ENV}
ENV PORT=3000

# 5. File Operations
COPY package*.json ./

# 6. Build execution
RUN npm ci --only=production

# Copy remaining source code
COPY . .

# 7. Storage and Networking
VOLUME ["/app/logs"]
EXPOSE 3000

# 8. Security Non-Root User
USER node

# 9. Execution Runtime
ENTRYPOINT ["node"]
CMD ["server.js"]
```