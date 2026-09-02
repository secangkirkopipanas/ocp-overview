# Workshop Task: OpenShift Service Mesh — Architecture, Control Plane, Data Plane, Sidecars, and Ingress Gateway

## Objective

Deploy **OpenShift Service Mesh** (Istio) and the sample **webstore** application using **sidecar** mode.

You will:

* Identify the **control plane** and **data plane**
* Install (or inspect) the Istio control plane
* Enroll an application namespace in the mesh
* Confirm **sidecar** injection on application Pods
* Expose the application through the **Istio Ingress Gateway** and an OpenShift Route

This is **part 1**. Use sidecar mode only (`webstore-dev`). Do not use the ambient / UAT overlay yet.

### Requirements

| Requirement        | Value                                      |
| ------------------ | ------------------------------------------ |
| Mesh namespace     | `istio-system`                             |
| Application project| `webstore-dev`                             |
| Dataplane mode     | Sidecar (`istio-injection=enabled`)        |
| Ingress            | Istio Ingress Gateway + Route `ingress-gateway` |
| Manifests          | `service-mesh/`                            |

---

## Architecture to Build

```text
                         Internet
                            │
                            │ HTTPS
                            ▼
                    OpenShift Route
                     ingress-gateway
                            │
                            │ HTTP
                            ▼
                  Istio Ingress Gateway
                     (data plane)
                            │
                     VirtualService
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
           mesh-ui        user          order / product
         + sidecar     + sidecar         + sidecar
                            │
                            ▼
                          Redis
                         + sidecar


     Control plane (istiod in istio-system)
     configures all sidecars and the gateway
```

---

## Task 1 — Understand Control Plane vs Data Plane

A service mesh has two parts:

| Plane          | What it is                                      | In this lab                          |
| -------------- | ----------------------------------------------- | ------------------------------------ |
| Control plane  | Configures the mesh. Does not carry app traffic | `istiod` in `istio-system`           |
| Data plane     | Proxies that carry application traffic          | `istio-proxy` sidecars + ingress gateway |

Before installing anything, open:

```text
service-mesh/istio/istio.yaml
```

Find:

* The `Istio` custom resource (this tells the Sail Operator to create the control plane)
* `spec.namespace: istio-system`
* `discoverySelectors` with label `istio-discovery: enabled`

Only namespaces with `istio-discovery=enabled` are visible to the control plane.

---

## Task 2 — Install the Control Plane

Operators must already be installed (OpenShift Service Mesh 3 / Sail Operator).

Apply the control plane:

```bash
oc apply -f service-mesh/istio/istio.yaml
```

Wait until it is ready:

```bash
oc get istio
oc get pods -n istio-system
```

Expected: an `istiod` Pod in `Running` state.

Inspect the control plane:

```bash
oc get deploy -n istio-system
oc logs -n istio-system deploy/istiod --tail=20
```

Optional (needed later for ambient; useful now so CNI is present):

```bash
oc apply -f service-mesh/istio/istio-cni.yaml
oc get pods -n istio-cni
```

> If the instructor already installed the control plane, skip `oc apply` and only run the inspect commands.

---

## Task 3 — Enroll the Application Namespace (Data Plane)

Open:

```text
service-mesh/apps/manifest/overlays/dev/ns.yaml
```

The namespace must have **both** labels:

| Label                    | Purpose                                      |
| ------------------------ | -------------------------------------------- |
| `istio-discovery=enabled`| Control plane discovers this namespace       |
| `istio-injection=enabled`| New Pods get an Envoy **sidecar**            |

Deploy the sample application:

```bash
oc apply -k service-mesh/apps/manifest/overlays/dev
```

Switch to the project:

```bash
oc project webstore-dev
```

Verify the labels:

```bash
oc get namespace webstore-dev --show-labels
```

---

## Task 4 — Verify Sidecars

List Pods:

```bash
oc get pods -n webstore-dev
```

Application Pods should show **two** containers, for example `2/2 READY`:

```text
NAME                      READY   STATUS    RESTARTS
mesh-ui-xxxxx             2/2     Running   0
order-xxxxx               2/2     Running   0
product-xxxxx             2/2     Running   0
user-xxxxx                2/2     Running   0
redis-xxxxx               2/2     Running   0
istio-ingressgateway-xxx  1/1     Running   0
```

The extra container is the sidecar. Confirm the container names:

```bash
oc get pod -n webstore-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

You should see `istio-proxy` next to the application container (for example `order` `istio-proxy`).

Describe one workload:

```bash
oc describe pod -n webstore-dev -l app=order
```

Look for:

* Init container `istio-init` or CNI redirection
* Container `istio-proxy`
* Annotation `sidecar.istio.io/status`

The sidecar **is** the data plane for that Pod. Application traffic in and out of the Pod goes through Envoy.

---

## Task 5 — Inspect the Istio Ingress Gateway

The ingress gateway is a data-plane proxy at the edge of the mesh. It is **not** the same as an OpenShift router by itself: the Route only forwards traffic to the gateway Service.

Open:

```text
service-mesh/apps/manifest/base/deployments/istio-ingress-gateway.yaml
```

Find:

* Label `istio: ingressgateway`
* Annotation `inject.istio.io/templates: gateway` (gateway proxy, not an app sidecar)
* `sidecar.istio.io/inject: "true"`
* OpenShift Route `ingress-gateway` targeting Service `istio-ingressgateway`

Verify the gateway Pod and Service:

```bash
oc get pods,svc,route -n webstore-dev -l istio=ingressgateway
oc get route ingress-gateway -n webstore-dev
```

The Istio `Gateway` resource selects that workload:

```bash
oc get gateway -n webstore-dev -o yaml
```

The `VirtualService` attaches to that Gateway and routes by path:

```bash
oc get virtualservice -n webstore-dev -o yaml
```

| Path            | Destination         |
| --------------- | ------------------- |
| `/`, `/assets/` | `mesh-ui-service`   |
| `/svc/user`     | `user-service`      |
| `/svc/order`    | `order-service`     |
| `/svc/product`  | `product-service`   |

---

## Task 6 — Send Traffic Through the Gateway

Get the Route URL:

```bash
oc get route ingress-gateway -n webstore-dev \
  -o jsonpath='https://{.spec.host}{"\n"}'
```

Open the URL in a browser. You should see the webstore UI.

From the CLI, hit the UI and one backend path:

```bash
ROUTE=$(oc get route ingress-gateway -n webstore-dev -o jsonpath='{.spec.host}')

curl -k "https://${ROUTE}/"
curl -k "https://${ROUTE}/svc/product"
```

Traffic flow:

```text
curl / browser
      │
      ▼
OpenShift Route  (TLS edge)
      │
      ▼
Service istio-ingressgateway
      │
      ▼
Istio Ingress Gateway Pod  (Envoy router)
      │
      ▼
VirtualService match on URI
      │
      ▼
App Pod  →  istio-proxy sidecar  →  application container
```

---

## Task 7 — Prove New Pods Get Sidecars Automatically

Scale one service:

```bash
oc scale deployment order -n webstore-dev --replicas=2
```

```bash
oc get pods -n webstore-dev -l app=order
```

The new Pod should also be `2/2` with an `istio-proxy` container. You did not change the Deployment template; **namespace injection** added the sidecar.

Scale back:

```bash
oc scale deployment order -n webstore-dev --replicas=1
```

---

## Bonus Challenge — Compare a Sidecar with the Gateway Proxy

Application sidecar (in-pod proxy):

```bash
oc get pod -n webstore-dev -l app=mesh-ui \
  -o jsonpath='{.items[0].spec.containers[*].name}{"\n"}'
```

Ingress gateway (edge proxy, single `istio-proxy` container):

```bash
oc get pod -n webstore-dev -l istio=ingressgateway \
  -o jsonpath='{.items[0].spec.containers[*].name}{"\n"}'
```

Both are Envoy. The control plane (`istiod`) pushes configuration to both.

Optional: print sidecar identity from the admin port:

```bash
oc exec -n webstore-dev deploy/order -c istio-proxy -- \
  curl -s localhost:15000/server_info | head
```

---

## Expected Result

```text
istiod  (control plane)
   │
   │  configures
   ▼
┌──────────────────────────────────────────┐
│              webstore-dev                │
│                                          │
│   Ingress Gateway (data plane)           │
│              │                           │
│              ▼                           │
│   UI / user / order / product / redis    │
│   each with istio-proxy sidecar          │
└──────────────────────────────────────────┘
```

---

## Challenge

Without looking at the overlay, answer:

1. What happens if you create a namespace with only `istio-injection=enabled` and **without** `istio-discovery=enabled`?
2. What happens if you remove `istio-injection=enabled` and restart the `order` Pods?
3. Why does the ingress gateway use `inject.istio.io/templates: gateway` instead of the default sidecar template?

Restart `order` after removing the injection label only if you are comfortable rolling the workload back (re-apply the overlay to restore labels).

---

## Learning Objectives

After completing this exercise, you should understand:

* The difference between the **control plane** (`istiod`) and the **data plane** (proxies)
* How the `Istio` resource installs the control plane
* Why namespaces need `istio-discovery` and `istio-injection` labels
* How a **sidecar** (`istio-proxy`) is injected into application Pods
* That new Pods in an injected namespace get a sidecar automatically
* How the **Istio Ingress Gateway** sits at the edge of the mesh
* How an OpenShift Route forwards TLS traffic to the gateway Service
* How a `Gateway` + `VirtualService` route HTTP paths to mesh services
