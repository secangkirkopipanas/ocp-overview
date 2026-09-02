# OpenShift Service Mesh Workshop

This directory deploys **Red Hat OpenShift Service Mesh 3** (Sail Operator / Istio) with a sample webstore application, plus Kiali and Grafana for traffic visualization.

It demonstrates two dataplane modes on the same control plane:

| Namespace      | Mode     | How traffic is captured                         |
| -------------- | -------- | ----------------------------------------------- |
| `webstore-dev` | Sidecar  | `istio-injection=enabled` injects `istio-proxy` |
| `webstore-uat` | Ambient  | ztunnel (L4). HTTP/L7 needs a waypoint proxy    |

```text
                    OpenShift Route (ingress-gateway)
                                |
                     Istio Ingress Gateway
                                |
              VirtualService routes by path
           /  /svc/user  /svc/order  /svc/product
          UI    user       order      product
                         \    |    /
                           Redis
```

STRICT mTLS is enabled in each application namespace via `PeerAuthentication`.

## Directory Structure

```text
service-mesh/
├── istio/                          # Control plane and observability
│   ├── user-workload-monitoring.yaml
│   ├── istio.yaml                  # Istio CR, Telemetry, istiod/proxy scrapes
│   ├── istio-cni.yaml              # IstioCNI (required for ambient)
│   ├── kiali.yaml
│   ├── cluster-role.yaml
│   ├── util-pod.yaml
│   └── grafana/
│       ├── grafana.yaml            # Grafana + Thanos datasource
│       ├── kustomization.yaml
│       └── dashboards/             # Service Mesh Traffic + Istio dashboards
└── apps/manifest/
    ├── base/                       # Webstore app, gateway, proxy PodMonitor
    └── overlays/
        ├── dev/                    # webstore-dev (sidecar)
        └── uat/                    # webstore-uat (ambient)
```

## Prerequisites

You will need:

* An OpenShift cluster and `oc` CLI
* Cluster-admin (or equivalent) to enable user-workload monitoring
* Operators installed from OperatorHub:
  * **OpenShift Service Mesh 3** (Sail Operator)
  * **Kiali Operator provided by Red Hat** (not the community operator)
* Permission to create namespaces, routes, and `ClusterRoleBinding` objects

Confirm the operators are ready:

```bash
oc get csv -A | grep -E 'servicemesh|kiali|sail'
```

## 1. Enable User-Workload Monitoring

Kiali and Grafana read Istio metrics from the OpenShift monitoring stack (Thanos). User-workload monitoring must be enabled so Prometheus scrapes mesh namespaces.

```bash
oc apply -f service-mesh/istio/user-workload-monitoring.yaml
```

Wait until the user-workload Prometheus is up:

```bash
oc get pods -n openshift-user-workload-monitoring
```

## 2. Install the Istio Control Plane

```bash
oc apply -f service-mesh/istio/istio.yaml
```

This creates:

* `istio-system` (labeled `istio-discovery=enabled`)
* `Istio` `default` with discovery limited to namespaces that have that label
* A mesh `Telemetry` resource that enables the Prometheus metrics provider
* `PodMonitor` / `ServiceMonitor` objects for istiod and proxies **in `istio-system`**

Wait until the control plane is healthy:

```bash
oc get istio default -n istio-system
oc get pods -n istio-system
```

## 3. Install Istio CNI

CNI is required for ambient mode and recommended for sidecar redirection.

```bash
oc apply -f service-mesh/istio/istio-cni.yaml
```

```bash
oc get istiocni default -n istio-cni
oc get pods -n istio-cni
```

Optional cluster roles for mesh management:

```bash
oc apply -f service-mesh/istio/cluster-role.yaml
```

## 4. Install Kiali

```bash
oc apply -f service-mesh/istio/kiali.yaml
```

Kiali uses OpenShift authentication and queries Thanos as the Kiali service account (`cluster-monitoring-view`).

```bash
echo "https://$(oc get route kiali -n istio-system -o jsonpath='{.spec.host}')"
```

## 5. Install Grafana

Grafana is provisioned with a Prometheus datasource pointed at Thanos and Istio dashboards. Dashboards are split across ConfigMaps so they stay under the 256KiB `last-applied-configuration` annotation limit.

```bash
oc apply -k service-mesh/istio/grafana
```

```bash
echo "https://$(oc get route grafana -n istio-system -o jsonpath='{.spec.host}')"
```

Anonymous view is enabled. Sign in as `admin` / `admin` to edit.

| Dashboard                 | Location        |
| ------------------------- | --------------- |
| Service Mesh Traffic      | Home            |
| Istio Mesh / Performance / Control Plane | Istio folder |
| Istio Service             | Istio folder    |
| Istio Workload            | Istio folder    |

Kiali **View in Grafana** links are enabled in `kiali.yaml`.

## 6. Deploy the Sample Application

### Sidecar mesh (`webstore-dev`)

```bash
oc apply -k service-mesh/apps/manifest/overlays/dev
```

Confirm sidecars were injected (`2/2` containers):

```bash
oc get pods -n webstore-dev
oc get pod -n webstore-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

### Ambient mesh (`webstore-uat`)

```bash
oc apply -k service-mesh/apps/manifest/overlays/uat
```

Pods do not get a sidecar. Traffic is redirected by ztunnel. Without a waypoint (`istio.io/use-waypoint` is commented out in `overlays/uat/ns.yaml`), Kiali shows **L4/TCP** only.

The overlay deploys:

* `mesh-ui`, `user`, `order`, `product`, `redis`, `util`
* Istio ingress gateway (injected gateway template) and OpenShift Route
* `Gateway` + `VirtualService` path routing
* `PeerAuthentication` `STRICT`
* `istio-proxies-monitor` `PodMonitor` in the application namespace

Open the storefront:

```bash
echo "https://$(oc get route ingress-gateway -n webstore-dev -o jsonpath='{.spec.host}')"
```

Use `-n webstore-uat` for the ambient overlay.

| Path            | Backend             |
| --------------- | ------------------- |
| `/`, `/assets/` | `mesh-ui-service`   |
| `/svc/user`     | `user-service`      |
| `/svc/order`    | `order-service`     |
| `/svc/product`  | `product-service`   |

## 7. Verify Mesh Traffic

Generate traffic through the UI or with `curl` against the route. Metrics can take a minute to appear.

In the OpenShift console, go to **Observe → Metrics** and run:

```promql
istio_requests_total
```

For ambient L4 (no waypoint):

```promql
istio_tcp_connections_opened_total
```

Then open:

* **Kiali** → Graph for `webstore-dev` (HTTP) or `webstore-uat` (TCP until a waypoint is added)
* **Grafana** → **Service Mesh Traffic**, set the namespace variable

### Why the proxy PodMonitor is in every mesh namespace

OpenShift user-workload monitoring **ignores** `spec.namespaceSelector` on `PodMonitor` / `ServiceMonitor`. A monitor in `istio-system` only scrapes that namespace.

Kiali graphs are built from Envoy `istio_*` metrics (`/stats/prometheus` on `istio-proxy`), not from application `/metrics` endpoints. That is why `istio-proxies-monitor` is applied in `istio-system` and again in each app overlay.

NetworkPolicies in the app namespaces allow scrapes from OpenShift monitoring and `openshift-user-workload-monitoring`.

## 8. Cleanup

```bash
oc delete -k service-mesh/apps/manifest/overlays/dev --ignore-not-found
oc delete -k service-mesh/apps/manifest/overlays/uat --ignore-not-found
oc delete -k service-mesh/istio/grafana --ignore-not-found
oc delete -f service-mesh/istio/kiali.yaml --ignore-not-found
oc delete -f service-mesh/istio/istio.yaml --ignore-not-found
oc delete -f service-mesh/istio/istio-cni.yaml --ignore-not-found
```

Do not remove `user-workload-monitoring.yaml` unless you intend to disable monitoring for all user projects on the cluster.
