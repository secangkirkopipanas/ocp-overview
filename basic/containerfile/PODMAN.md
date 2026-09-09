# Podman Cheat Sheet

A practical Podman command reference for OpenShift and container development.

## 1. Check Podman

```bash
podman --version
podman info
```

Check available commands:

```bash
podman --help
```

---

## 2. Search and Pull Images

Search available images:

```bash
podman search nginx
```

Pull an image:

```bash
podman pull nginx:latest
```

Pull from a registry:

```bash
podman pull registry.access.redhat.com/ubi9/ubi:latest
```

List local images:

```bash
podman images
```

Inspect an image:

```bash
podman inspect nginx:latest
```

Remove an image:

```bash
podman rmi nginx:latest
```

Remove unused images:

```bash
podman image prune
```

---

## 3. Run Containers

Run a container:

```bash
podman run nginx
```

Run in the background:

```bash
podman run -d nginx
```

Assign a name:

```bash
podman run -d --name my-nginx nginx
```

Publish a port:

```bash
podman run -d \
  --name my-nginx \
  -p 8080:80 \
  nginx
```

Run interactively:

```bash
podman run -it ubi9/ubi bash
```

Run with environment variables:

```bash
podman run -d \
  --name my-app \
  -e APP_ENV=dev \
  nginx
```

Automatically remove the container when it exits:

```bash
podman run --rm nginx
```

---

## 4. Container Management

List running containers:

```bash
podman ps
```

List all containers:

```bash
podman ps -a
```

Start a container:

```bash
podman start my-nginx
```

Stop a container:

```bash
podman stop my-nginx
```

Restart a container:

```bash
podman restart my-nginx
```

Remove a container:

```bash
podman rm my-nginx
```

Force remove a running container:

```bash
podman rm -f my-nginx
```

View container details:

```bash
podman inspect my-nginx
```

View resource usage:

```bash
podman stats
```

---

## 5. Container Logs

View logs:

```bash
podman logs my-nginx
```

Follow logs:

```bash
podman logs -f my-nginx
```

Show the last 100 lines:

```bash
podman logs --tail 100 my-nginx
```

---

## 6. Execute Commands in Containers

Execute a command:

```bash
podman exec my-nginx ls
```

Open a shell:

```bash
podman exec -it my-nginx bash
```

For images without `bash`:

```bash
podman exec -it my-nginx sh
```

---

## 7. Copy Files

Copy a file into a container:

```bash
podman cp ./config.yaml my-nginx:/etc/config.yaml
```

Copy a file from a container:

```bash
podman cp my-nginx:/etc/nginx/nginx.conf ./nginx.conf
```

---

## 8. Port and Network Information

Show published ports:

```bash
podman port my-nginx
```

List networks:

```bash
podman network ls
```

Inspect a network:

```bash
podman network inspect podman
```

Inspect container networking:

```bash
podman inspect my-nginx
```

---

## 9. Environment Variables

Show environment variables configured in a container:

```bash
podman inspect my-nginx \
  --format '{{range .Config.Env}}{{println .}}{{end}}'
```

Set multiple variables:

```bash
podman run -d \
  --name my-app \
  -e APP_ENV=dev \
  -e APP_VERSION=1.0 \
  nginx
```

---

## 10. Build an Image

Build using a `Containerfile`:

```bash
podman build -t my-app:1.0 .
```

Build using a specific file:

```bash
podman build \
  -f Containerfile \
  -t my-app:1.0 .
```

List images:

```bash
podman images
```

Run the newly built image:

```bash
podman run -d --name my-app my-app:1.0
```

---

## 11. Tag Images

Tag an image:

```bash
podman tag my-app:1.0 my-app:latest
```

Tag for a registry:

```bash
podman tag my-app:1.0 \
  quay.io/myuser/my-app:1.0
```

For an OpenShift internal registry:

```bash
podman tag my-app:1.0 \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/my-app:1.0
```

---

# 12. Registry Login

Login to a container registry:

```bash
podman login <registry>
```

Example:

```bash
podman login quay.io
```

Logout:

```bash
podman logout quay.io
```

View registry credentials:

```bash
cat ~/.config/containers/auth.json
```

> Do not share or commit `auth.json`. It may contain registry credentials or authentication tokens.

---

# 13. OpenShift Internal Registry

Get the OpenShift registry route:

```bash
oc get route default-route \
  -n openshift-image-registry
```

Login to OpenShift:

```bash
oc login https://api.<cluster-domain>:6443 \
  -u user1 \
  -p '<password>'
```

Get the current OpenShift OAuth token:

```bash
oc whoami -t
```

Login to the OpenShift registry using the OAuth token:

```bash
podman login \
  -u user1 \
  -p "$(oc whoami -t)" \
  default-route-openshift-image-registry.apps.<cluster-domain>
```

Alternatively, use:

```bash
oc registry login \
  --registry=default-route-openshift-image-registry.apps.<cluster-domain>
```

Verify the logged-in user:

```bash
podman login --get-login \
  default-route-openshift-image-registry.apps.<cluster-domain>
```

---

# 14. Push to OpenShift ImageStream

Assume:

- User: `user1`
- Namespace: `workshop1`
- ImageStream: `todo`
- Registry: `default-route-openshift-image-registry.apps.<cluster-domain>`

Tag the image:

```bash
podman tag my-app:1.0 \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/todo:1.0
```

Push the image:

```bash
podman push \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/todo:1.0
```

Verify the ImageStream:

```bash
oc get is -n workshop1
```

Verify the ImageStream tag:

```bash
oc get istag -n workshop1
```

Describe the ImageStream:

```bash
oc describe is todo -n workshop1
```

---

# 15. Pull from OpenShift ImageStream

Login first:

```bash
podman login \
  -u user1 \
  -p "$(oc whoami -t)" \
  default-route-openshift-image-registry.apps.<cluster-domain>
```

Pull:

```bash
podman pull \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/todo:1.0
```

Pull the latest tag:

```bash
podman pull \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/todo:latest
```

---

# 16. OpenShift ImageStream Naming

The general format is:

```text
<registry>/<namespace>/<imagestream>:<tag>
```

Example:

```text
default-route-openshift-image-registry.apps.cluster.example.com/workshop1/todo:latest
```

For the workshop environment:

```text
user1  -> workshop1
user2  -> workshop2
user3  -> workshop3
...
user10 -> workshop10
```

Example for `user5`:

```text
default-route-openshift-image-registry.apps.<cluster-domain>/workshop5/todo:latest
```

---

# 17. Image History

View image history:

```bash
podman history my-app:1.0
```

---

# 18. Save and Load Images

Save an image to a tar file:

```bash
podman save \
  -o my-app.tar \
  my-app:1.0
```

Load an image:

```bash
podman load -i my-app.tar
```

---

# 19. Export and Import Containers

Export a container filesystem:

```bash
podman export \
  -o my-container.tar \
  my-container
```

Import it as an image:

```bash
podman import \
  my-container.tar \
  my-imported-image:latest
```

> `podman save/load` preserves an image and its layers. `podman export/import` works with a container filesystem and does not preserve the original image metadata in the same way.

---

# 20. Volume Management

List volumes:

```bash
podman volume ls
```

Create a volume:

```bash
podman volume create my-data
```

Inspect a volume:

```bash
podman volume inspect my-data
```

Mount a volume:

```bash
podman run -d \
  --name my-app \
  -v my-data:/data \
  nginx
```

Remove a volume:

```bash
podman volume rm my-data
```

---

# 21. Bind Mounts

Mount a local directory:

```bash
podman run -d \
  --name my-nginx \
  -v "$PWD/html:/usr/share/nginx/html:Z" \
  -p 8080:80 \
  nginx
```

The `:Z` option is useful on SELinux-enabled systems when the container needs appropriate access to the mounted files.

---

# 22. Cleanup

Remove stopped containers:

```bash
podman container prune
```

Remove unused images:

```bash
podman image prune
```

Remove unused resources:

```bash
podman system prune
```

Check disk usage:

```bash
podman system df
```

---

# 23. Troubleshooting

Check Podman information:

```bash
podman info
```

Check container state:

```bash
podman ps -a
```

Check logs:

```bash
podman logs <container>
```

Inspect the container:

```bash
podman inspect <container>
```

Check image:

```bash
podman inspect <image>
```

Test registry login:

```bash
podman login <registry>
```

Check OpenShift permissions:

```bash
oc auth can-i get imagestreams/layers -n workshop1
oc auth can-i update imagestreams/layers -n workshop1
```

Check current OpenShift identity:

```bash
oc whoami
```

Check OAuth token:

```bash
oc whoami -t
```

Check registry route:

```bash
oc get route default-route \
  -n openshift-image-registry
```

---

# 24. Common OpenShift Registry Error

### Error

```text
Error: logging into "...":
invalid username/password
```

### Solution

Do not normally use the user's OpenShift password directly with `podman login`.

Use the OpenShift OAuth token:

```bash
podman login \
  -u user1 \
  -p "$(oc whoami -t)" \
  default-route-openshift-image-registry.apps.<cluster-domain>
```

Or:

```bash
oc registry login \
  --registry=default-route-openshift-image-registry.apps.<cluster-domain>
```

---

# 25. Quick Workflow: Build → Tag → Login → Push

```bash
# Build
podman build -t my-app:1.0 .

# Login to OpenShift
oc login https://api.<cluster-domain>:6443 \
  -u user1 \
  -p '<password>'

# Login to registry using OAuth token
podman login \
  -u user1 \
  -p "$(oc whoami -t)" \
  default-route-openshift-image-registry.apps.<cluster-domain>

# Tag
podman tag my-app:1.0 \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/todo:1.0

# Push
podman push \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/todo:1.0

# Verify
oc get istag -n workshop1
```

---

# 26. Quick Workflow: Login → Pull → Run

```bash
# Login
podman login \
  -u user1 \
  -p "$(oc whoami -t)" \
  default-route-openshift-image-registry.apps.<cluster-domain>

# Pull
podman pull \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/todo:1.0

# Run
podman run -d \
  --name todo \
  -p 8080:8080 \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/todo:1.0
```

---

## Essential Commands

| Task | Command |
|---|---|
| List images | `podman images` |
| Pull image | `podman pull <image>` |
| Build image | `podman build -t <image> .` |
| Run container | `podman run <image>` |
| Run detached | `podman run -d <image>` |
| List containers | `podman ps -a` |
| Start | `podman start <container>` |
| Stop | `podman stop <container>` |
| Remove container | `podman rm <container>` |
| Remove image | `podman rmi <image>` |
| Logs | `podman logs <container>` |
| Shell | `podman exec -it <container> bash` |
| Inspect | `podman inspect <container>` |
| Tag | `podman tag <source> <target>` |
| Login | `podman login <registry>` |
| Push | `podman push <image>` |
| Pull | `podman pull <image>` |
| Image history | `podman history <image>` |
| Disk usage | `podman system df` |
| Cleanup | `podman system prune` |

---

## OpenShift Registry Essentials

```bash
# Current OpenShift user
oc whoami

# Current OAuth token
oc whoami -t

# Registry route
oc get route default-route -n openshift-image-registry

# Login
oc registry login \
  --registry=default-route-openshift-image-registry.apps.<cluster-domain>

# Tag
podman tag my-app:latest \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/todo:latest

# Push
podman push \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/todo:latest

# Pull
podman pull \
  default-route-openshift-image-registry.apps.<cluster-domain>/workshop1/todo:latest
```
