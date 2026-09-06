# Todo OpenShift Service Mesh manifests

Kustomize base plus `dev` (`todo-dev`) and `prod` (`todo-prod`) overlays for the two-service todo app.

Application source and images: `apps/todo/`.

```text
manifest/
├── base/
│   ├── redis.yaml, user.yaml, todo.yaml
│   ├── istio-ingress-gateway.yaml   # Envoy ingress + OpenShift Route
│   ├── istio-external-gateway.yaml  # Istio Gateway CR
│   ├── istio-virtual-service.yaml   # /api/users, /api/todos, UI
│   ├── peer-authentication.yaml     # STRICT mTLS
│   ├── destination-rules.yaml       # ISTIO_MUTUAL + subsets v1
│   ├── envoy-filter.yaml            # Lua response headers on ingress
│   ├── istio-proxies-podmonitor.yaml
│   ├── service-monitors.yaml
│   ├── telemetry.yaml
│   └── network-policies.yaml
└── overlays/
    ├── dev/
    └── prod/
```

Namespaces are labeled `istio-injection: enabled` and `istio-discovery: enabled`.

## Traffic flow

```text
OpenShift Route (todo-ingress)
        │
        ▼
istio-ingressgateway (Envoy) + EnvoyFilter Lua headers
        │
        ▼
Istio Gateway (todo-gateway) + VirtualService
        │
        ├── /api/users/*  → user:8080 (subset v1)
        ├── /api/todos/*  → todo:8080 (subset v1)
        └── /*            → todo:8080 (UI)
```

East-west: **todo** calls **user** over mTLS to resolve owner names. Both services use **Redis** (in-memory, no persistence).

## Apply

Requires OpenShift Service Mesh / Istio control plane from `service-mesh/istio/`.

```bash
oc apply -k service-mesh/apps/todo/manifest/overlays/dev
oc get route todo-ingress -n todo-dev -o jsonpath='https://{.spec.host}{"\n"}'
```

Use that **todo-dev** Route host, not the webstore Route.

The todo ingress Gateway selects `istio: todo-ingressgateway` so it does not share Envoy config with `webstore-dev` (which uses `istio: ingressgateway` and `hosts: "*"`). If you already deployed the old selector, delete the ingress Deployment first (the label selector is immutable):

```bash
oc delete deploy/istio-ingressgateway -n todo-dev
oc apply -k service-mesh/apps/todo/manifest/overlays/dev
```

Re-apply the Istio CR if you want namespace-scoped gateways mesh-wide:

```bash
oc apply -f service-mesh/istio/istio.yaml
```

## Images

| Image | Dockerfile |
| ----- | ---------- |
| `quay.io/rh_rh/ocp-todo` | `apps/todo/backends/todo/Dockerfile` |
| `quay.io/rh_rh/ocp-todo-user` | `apps/todo/backends/user/Dockerfile` |

```bash
cd apps/todo
TAG=latest ./build-image.sh
```

## Workshop checks

```bash
# Sidecars (expect 2/2 on todo, user, redis; gateway uses the gateway template)
oc get pods -n todo-dev

oc get peerauthentication,destinationrule,virtualservice,gateway,envoyfilter -n todo-dev
oc get podmonitor,servicemonitor -n todo-dev

# Lua EnvoyFilter headers
ROUTE=$(oc get route todo-ingress -n todo-dev -o jsonpath='{.spec.host}')
curl -sSI "https://${ROUTE}/" | grep -iE 'x-workshop-mesh|x-todo-filter'

# East-west: todo → user
oc exec -n todo-dev deploy/todo -c todo -- \
  curl -sS http://user:8080/api/users
```

`PeerAuthentication` `STRICT` plus `DestinationRule` `ISTIO_MUTUAL` is the usual teaching pair: server policy vs client policy. Redis stays in the mesh; exec probes (`redis-cli ping`) talk to localhost and do not need mTLS.
