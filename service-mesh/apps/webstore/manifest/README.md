# WebStore OpenShift manifests

Kustomize base plus `dev` and `prod` overlays for the workshop storefront on OpenShift Service Mesh.

```text
app/manifest/
├── base/
│   ├── postgres.yaml, account.yaml, products.yaml, …
│   ├── istio-ingress-gateway.yaml   # Envoy ingress + OpenShift Route
│   ├── istio-external-gateway.yaml  # Istio Gateway CR
│   ├── istio-virtual-service.yaml   # path routing (/svc/* → APIs, / → UI)
│   ├── peer-authentication.yaml
│   ├── istio-proxies-podmonitor.yaml
│   ├── service-monitors.yaml
│   └── network-policies.yaml
└── overlays/
    ├── dev/
    └── prod/
```

Namespaces are labeled `istio-injection: enabled` so application pods join the mesh.

## Do you need an nginx gateway?

**No** — not on OCP with Istio. The mesh gives you two different “gateway” concepts:

| Resource | Required? | Role |
| -------- | --------- | ---- |
| **Istio `Gateway`** (`istio-external-gateway.yaml`) | Yes | Tells the ingress gateway Envoy which host/port to listen on |
| **Istio `VirtualService`** | Yes | L7 routing: `/svc/account` → account, `/svc/products/api/v2` → products-v2, `/` → UI |
| **nginx `gateway` Deployment** | No | Only used in Docker Compose locally; removed from these manifests |

External traffic: **OpenShift Route → istio-ingressgateway → VirtualService → services**.

## Traffic flow

```text
OpenShift Route (webstore-ingress)
        │
        ▼
istio-ingressgateway (Envoy)
        │
        ▼
Istio Gateway (webstore-gateway) + VirtualService
        │
        ├── /svc/account/*     → account:8080
        ├── /svc/products/api/v2/* → products-v2:8080
        ├── /svc/products/api/v1/* → products:8080 (100%, or 90/10 split when `X-Canary-Split: true`)
        ├── /svc/order/*       → order:8080
        ├── /svc/payment/*     → payment:8080
        └── /*                 → ui:8080
```

## Apply

Requires OpenShift Service Mesh / Istio control plane installed.

```bash
oc apply -k app/manifest/overlays/dev
oc get route webstore-ingress -n webstore-dev -o jsonpath='https://{.spec.host}{"\n"}'
```

Local development still uses `docker-compose` (nginx gateway on port 8080).

## Images

| Image | Dockerfile |
| ----- | ---------- |
| `quay.io/rh_rh/ocp-webstore-account` | `backends/account/Dockerfile` |
| `quay.io/rh_rh/ocp-webstore-products` | `backends/products/Dockerfile` |
| `quay.io/rh_rh/ocp-webstore-order` | `backends/order/Dockerfile` |
| `quay.io/rh_rh/ocp-webstore-payment` | `backends/payment/Dockerfile` |
| `quay.io/rh_rh/ocp-webstore-ui` | `ui/Dockerfile` |

```bash
TAG=latest ./build-image.sh
```

## Mesh notes

- `PeerAuthentication` enforces **STRICT** mTLS between meshed pods.
- The ingress gateway Deployment uses the `gateway` injection template.
- NetworkPolicies allow ingress from the OpenShift router, monitoring, `istio-system`, `istio-cni`, and any namespace labeled `istio-discovery: enabled` (mesh namespaces). Egress to those namespaces plus cluster DNS is also allowed.
- All Deployments define **startup**, **readiness**, and **liveness** probes (`/health` for APIs, `/metrics` for UI, `pg_isready` for Postgres, `/healthz/ready` on the ingress gateway Envoy).

## Monitoring

User-workload Prometheus picks up resources labeled `openshift.io/user-monitoring: "true"`.

| Resource | Target | Metrics |
| -------- | ------ | ------- |
| **PodMonitor** `istio-proxies-monitor` | All injected `istio-proxy` sidecars | Envoy `/stats/prometheus` |
| **ServiceMonitor** per API service | account, products, products-v2, order, payment | FastAPI `/metrics` (`prometheus_client`) |
| **ServiceMonitor** `ui-service-monitor` | UI nginx | `/metrics` (`nginx_up` gauge) |
| **ServiceMonitor** `istio-ingressgateway-service-monitor` | Ingress gateway | Envoy `/stats/prometheus` on port `http-envoy-prom` |

Postgres has no Prometheus endpoint in this stack (no exporter). Rebuild and push images after changing `/metrics` support:

```bash
TAG=latest ./build-image.sh
```

## Kiali traffic graphs

Kiali is installed from `service-mesh/istio/kiali.yaml` and reads **Envoy** `istio_*` metrics via OpenShift Thanos — not application `/metrics` endpoints. See `service-mesh/README.md` sections 1, 4, and 7 for the full observability stack.

### Prerequisites (from `service-mesh/istio/`)

| Step | Manifest | Purpose |
| ---- | -------- | ------- |
| User-workload monitoring | `user-workload-monitoring.yaml` | Prometheus scrapes mesh namespaces |
| Istio control plane | `istio.yaml` | `discoverySelectors`, mesh `Telemetry`, istiod scrapes |
| Kiali | `kiali.yaml` | Graph UI → Thanos (`thanos_proxy: enabled`) |
| Per-namespace proxy scrape | `istio-proxies-podmonitor.yaml` | **Must live in each mesh namespace** |

OpenShift user-workload monitoring **ignores** `PodMonitor.spec.namespaceSelector`. A monitor only in `istio-system` does not scrape `webstore-dev` proxies.

### Verify on the cluster

```bash
# Sidecars injected (expect 2/2 on app pods)
oc get pods -n webstore-dev

# Proxy scrape targets (expect istio-proxies-monitor targets "up")
oc exec -n openshift-user-workload-monitoring prometheus-user-workload-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/targets' | grep -c webstore-dev

# Envoy metrics exist (expect > 0 after browsing the store)
oc exec -n openshift-user-workload-monitoring prometheus-user-workload-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=istio_requests_total{destination_workload_namespace="webstore-dev"}'

# Open Kiali → Graph → select namespace webstore-dev, interval "Last 5m", generate traffic
echo "https://$(oc get route kiali -n istio-system -o jsonpath='{.spec.host}')"
```

### Expected graph shape

Browser traffic enters via the OpenShift Route → `istio-ingressgateway` → VirtualService → services. You should see edges like:

```text
istio-ingressgateway → ui | account | products | order | payment
order → products | payment   (after checkout)
```

You will **not** see `ui → account` in Kiali: the React app calls `/svc/*` from the browser through the ingress gateway, not pod-to-pod from the UI container.

### Common reasons the graph looks empty

1. **PodMonitor missing** in `webstore-dev` — apply/re-apply manifests after adding `istio-proxies-podmonitor.yaml`.
2. **No traffic in the selected time window** — browse the store, then refresh Kiali with **Last 5m**.
3. **Wrong namespace** — graph must include `webstore-dev` (not only `istio-system`).
4. **Metrics lag** — allow ~1–2 minutes after first traffic for the 30s scrape interval.
5. **User-workload monitoring not enabled** — `oc get pods -n openshift-user-workload-monitoring`.
6. **Namespace labels** — `istio-injection: enabled` and `istio-discovery: enabled` on the namespace (see overlays).

## Canary routing (UI v2 + client IP)

Catalog canary uses **three** Istio rules (first match wins):

| Rule | Trigger | Routing |
| ---- | ------- | ------- |
| `canary-vip` | Client IP in `vip-xff-regex` (`X-Forwarded-For`) | **100%** `products-v2` |
| `canary-split-header` | UI **v2** → `X-Canary-Split: true` | **90/10** split |
| `canary-split-ip` | Client IP in `split-xff-regex` | **90/10** split |
| `products-v1-stable` | Everyone else | **100%** `products` |

Edit IPs in `manifest/overlays/dev/canary-ip-overrides.yaml` (dev) or `manifest/base/canary-ip-config.yaml` (defaults). Use `a^` to disable a list. Re-apply with `oc apply -k app/manifest/overlays/dev`.
