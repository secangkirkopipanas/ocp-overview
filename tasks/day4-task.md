# Workshop Task: OpenShift Service Mesh — mTLS, L7 Routing, and Certificate Authorities

## Objective

Continue from **day 3**. The sidecar mesh in `webstore-dev` is already running.

You will:

* Enforce and prove **mutual TLS (mTLS)** between workloads
* Inspect the mesh **certificate authority** and workload identities
* Read and change **Layer 7** routing rules (`VirtualService`, `DestinationRule`)

This is **part 2**. Stay on sidecar mode (`webstore-dev`). Do not switch to ambient / UAT.

### Requirements

| Requirement         | Value                         |
| ------------------- | ----------------------------- |
| Project             | `webstore-dev`                |
| Starting point      | Day 3 completed               |
| mTLS policy         | `PeerAuthentication` `STRICT` |
| Ingress routing     | `Gateway` + `VirtualService`  |
| Mesh CA             | Istiod (default)              |

---

## Architecture for Today

```text
                         Browser / curl
                                │
                         HTTPS (router cert)
                                │
                         OpenShift Route
                         (edge TLS — not mesh CA)
                                │
                                ▼
                      Istio Ingress Gateway
                                │
                    VirtualService (L7: path, rewrite)
                                │
                                ▼
                      mTLS (Istio CA / SPIFFE)
                     sidecar  <───>  sidecar
                      UI / user / order / product
```

Two different certificate systems are in play:

| Traffic                         | Who terminates TLS      | Which CA              |
| ------------------------------- | ----------------------- | --------------------- |
| User → OpenShift Route          | OpenShift ingress       | Router / cluster cert |
| Sidecar → sidecar (inside mesh) | Envoy (`istio-proxy`)   | **Istio CA** (istiod) |

---

## Task 1 — Inspect mTLS Policy

Open:

```text
service-mesh/apps/manifest/base/peer-auth.yaml
```

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT
```

A namespace `PeerAuthentication` named `default` applies to all workloads in that namespace.

| Mode        | Meaning                                          |
| ----------- | ------------------------------------------------ |
| `DISABLE`   | Plaintext only                                   |
| `PERMISSIVE`| Accept plaintext **or** mTLS (migration)         |
| `STRICT`    | Accept **only** mTLS                             |

`STRICT` is already applied with the day-3 overlay.

Verify:

```bash
oc project webstore-dev
oc get peerauthentication
oc get peerauthentication default -o yaml
```

---

## Task 2 — Prove mTLS from Inside the Mesh

The `util` Pod has a sidecar. Calls from `util` to another mesh Service are upgraded to mTLS by Envoy.

```bash
oc exec -n webstore-dev deploy/util -c util -- \
  curl -sS -o /dev/null -w "%{http_code}\n" http://product-service/
```

You should get an HTTP status from the product app (not a connection error).

Optional — same test to the other services:

```bash
oc exec -n webstore-dev deploy/util -c util -- curl -sS -o /dev/null -w "%{http_code} user\n" http://user-service/
oc exec -n webstore-dev deploy/util -c util -- curl -sS -o /dev/null -w "%{http_code} order\n" http://order-service/
```

The application container still uses **plain HTTP**. The sidecar wraps it in mTLS on the wire.

```text
util container --HTTP--> util sidecar --mTLS--> product sidecar --HTTP--> product container
```

---

## Task 3 — Prove STRICT Blocks Plaintext

Create a Pod **without** a sidecar in the same namespace:

```bash
oc apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: no-sidecar
  namespace: webstore-dev
  labels:
    app: no-sidecar
  annotations:
    sidecar.istio.io/inject: "false"
spec:
  containers:
    - name: curl
      image: quay.io/rh_rh/ubi9-util:latest
      command: ["tail", "-f", "/dev/null"]
EOF
```

Confirm it has only one container:

```bash
oc get pod no-sidecar -n webstore-dev
oc get pod no-sidecar -n webstore-dev -o jsonpath='{.spec.containers[*].name}{"\n"}'
```

Call product **without** mTLS:

```bash
oc exec -n webstore-dev no-sidecar -- \
  curl -sS -m 5 http://product-service/ || true
```

This should **fail** (timeout, reset, or connection refused). `STRICT` rejects plaintext.

Delete the test Pod when you are done:

```bash
oc delete pod no-sidecar -n webstore-dev
```

---

## Task 4 — Inspect the Mesh Certificate Authority

Istiod is the default **certificate authority** for the mesh. It issues short-lived workload certificates. Identities use **SPIFFE**:

```text
spiffe://cluster.local/ns/webstore-dev/sa/product-sa
```

List CA-related secrets in the control plane:

```bash
oc get secrets -n istio-system | grep -E 'ca|cert' || true
```

You should see something like `istio-ca-secret` (default self-signed root). A custom root would be a secret named `cacerts` instead.

Show the CA certificate:

```bash
oc get secret istio-ca-secret -n istio-system \
  -o jsonpath='{.data.ca-cert\.pem}' | base64 -d | openssl x509 -noout -subject -issuer -dates
```

Workload trust bundle (root the sidecar trusts):

```bash
oc exec -n webstore-dev deploy/product -c istio-proxy -- \
  ls -l /var/run/secrets/istio/
```

Decode the sidecar certificate (SPIFFE URI is in the SAN):

```bash
oc exec -n webstore-dev deploy/product -c istio-proxy -- \
  curl -s localhost:15000/certs
```

Look for `spiffe://` and the ServiceAccount name (`product-sa`). That identity is what mTLS authenticates, not the Pod IP.

Compare with the **Route** certificate (different CA):

```bash
ROUTE=$(oc get route ingress-gateway -n webstore-dev -o jsonpath='{.spec.host}')
echo | openssl s_client -connect "${ROUTE}:443" -servername "${ROUTE}" 2>/dev/null \
  | openssl x509 -noout -subject -issuer
```

That cert belongs to the OpenShift ingress / router, not to istiod.

---

## Task 5 — Read the L7 Routing Rules

Open:

```text
service-mesh/apps/manifest/base/deployments/virtual-service.yaml
service-mesh/apps/manifest/base/deployments/gateway.yaml
```

On the cluster:

```bash
oc get gateway,virtualservice -n webstore-dev
oc get virtualservice virtual-service -n webstore-dev -o yaml
```

The `VirtualService` is **Layer 7**: it matches HTTP URI, can rewrite the path, then picks a destination Service.

| Match                         | Rewrite | Destination         |
| ----------------------------- | ------- | ------------------- |
| `/` exact, `/assets/` prefix  | none    | `mesh-ui-service`   |
| `/svc/user`, `/svc/user/`     | `/`     | `user-service`      |
| `/svc/order`, `/svc/order/`   | `/`     | `order-service`     |
| `/svc/product`, `/svc/product/` | `/`   | `product-service`   |

Test from outside (still through the ingress gateway):

```bash
ROUTE=$(oc get route ingress-gateway -n webstore-dev -o jsonpath='{.spec.host}')

curl -k -sS -o /dev/null -w "%{http_code} UI\n"      "https://${ROUTE}/"
curl -k -sS -o /dev/null -w "%{http_code} product\n" "https://${ROUTE}/svc/product"
curl -k -sS -o /dev/null -w "%{http_code} order\n"   "https://${ROUTE}/svc/order"
```

A Service or kube-proxy alone cannot rewrite `/svc/product` → `/`. That is mesh L7 routing.

---

## Task 6 — Add a DestinationRule (Client-Side mTLS)

`PeerAuthentication` is the **server** policy (what inbound traffic is allowed). A `DestinationRule` is the **client** policy (how outbound calls to a host are made).

Create `product-destinationrule.yaml`:

```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: product
  namespace: webstore-dev
spec:
  host: product-service
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

Apply it:

```bash
oc apply -f product-destinationrule.yaml
```

```bash
oc get destinationrule -n webstore-dev
```

`ISTIO_MUTUAL` means: use the sidecar certificate issued by the **Istio CA** (not a generic TLS cert you mounted yourself).

Confirm product still works:

```bash
oc exec -n webstore-dev deploy/util -c util -- \
  curl -sS -o /dev/null -w "%{http_code}\n" http://product-service/
```

---

## Task 7 — Change an L7 Rule (Timeout)

Patch the product route with a **timeout**. This only exists at L7 (HTTP).

Edit the live VirtualService:

```bash
oc edit virtualservice virtual-service -n webstore-dev
```

Under the product `route`, add:

```yaml
    timeout: 2s
```

Example:

```yaml
  - match:
    - uri:
        exact: /svc/product
    - uri:
        prefix: /svc/product/
    rewrite:
      uri: /
    route:
    - destination:
        host: product-service
        port:
          number: 80
    timeout: 2s
```

Save and test:

```bash
ROUTE=$(oc get route ingress-gateway -n webstore-dev -o jsonpath='{.spec.host}')
curl -k -sS -o /dev/null -w "%{http_code} %{time_total}\n" "https://${ROUTE}/svc/product"
```

The call should still succeed if product responds in under 2 seconds.

Restore the original VirtualService when you are finished:

```bash
oc apply -k service-mesh/apps/manifest/overlays/dev
```

---

## Bonus Challenge — HTTP Fault Injection

Add a **fixed delay** on the product route (still on the VirtualService):

```yaml
    fault:
      delay:
        percentage:
          percent: 100
        fixedDelay: 3s
```

Call `/svc/product` again and watch the response time.

Remove the fault (re-apply the overlay) so the storefront stays usable.

---

## Challenge

1. Change `PeerAuthentication` from `STRICT` to `PERMISSIVE`, retry the `no-sidecar` Pod curl, then set it back to `STRICT`. What changed and why would you use `PERMISSIVE` in production?
2. Why can the browser use HTTPS while `util` still curls `http://product-service/`?
3. If you replaced the default Istio CA, which secret in `istio-system` would you create, and what happens to existing sidecars after the new root is trusted?

---

## Expected Result

```text
OpenShift Route          Istio Ingress Gateway
  (router CA)                  │
       │                       │  VirtualService (URI / rewrite / timeout)
       └───────────────────────┤
                               ▼
                    product-service
                               │
              DestinationRule ISTIO_MUTUAL
                               │
                    mTLS (Istio CA)
           spiffe://.../sa/product-sa
```

---

## Learning Objectives

After completing this exercise, you should understand:

* How `PeerAuthentication` `STRICT` enforces mTLS on inbound traffic
* Why a Pod without a sidecar cannot call a `STRICT` mesh Service
* That application containers still speak HTTP; Envoy provides mTLS
* That istiod is the default **mesh CA** and issues SPIFFE identities
* That the OpenShift Route certificate is a **different** CA from the mesh CA
* How a `VirtualService` matches HTTP paths and rewrites URIs (L7)
* How a `DestinationRule` with `ISTIO_MUTUAL` selects the mesh certificates on the client
* How L7 policies such as **timeout** and **fault injection** attach to HTTP routes
