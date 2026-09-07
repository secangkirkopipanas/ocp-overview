# OpenShift Service Mesh Hands-on Lab

## Overview

In this hands-on exercise, you will deploy a sample Todo application into your assigned OpenShift namespace and configure it to work with **OpenShift Service Mesh**.

You will configure:

* Todo application workloads
* Redis
* Istio ingress gateway
* Istio Gateway and VirtualService
* DestinationRules
* STRICT mTLS
* Prometheus ServiceMonitor and PodMonitor resources
* NetworkPolicies
* EnvoyFilter
* OpenShift Route

> **Important:** Perform all activities only in your assigned namespace.

---

## 1. Set Your Working Namespace

First, verify which namespace has been assigned to you.

```bash
oc project
```

If you need to switch to your assigned namespace:

```bash
oc project <your-namespace>
```

For convenience, set an environment variable:

```bash
export NAMESPACE=$(oc project -q)
```

Verify:

```bash
echo $NAMESPACE
```

You should see your assigned namespace, for example:

```text
workshop1
```

> **Note:** The examples in this guide use `$NAMESPACE` instead of a hard-coded namespace. This allows the same instructions to be used by all workshop participants.

---

# 2. Verify OpenShift Service Mesh

Before deploying the application, verify that the Service Mesh control plane is available.

Check the Service Mesh control plane:

```bash
oc get pods -n istio-system
```

You should see the Istio control-plane components running.

For example:

```text
NAME                             READY   STATUS
istiod-xxxxx                     1/1     Running
```

Verify the Istio CNI components:

```bash
oc get pods -n istio-cni
```

---

# 3. Prepare the Application Namespace

The namespace must be configured so that workloads can participate in the Service Mesh.

Check the namespace labels:

```bash
oc get namespace $NAMESPACE --show-labels
```

For sidecar-based Service Mesh, ensure the namespace has the appropriate Istio revision label.

For example:

```bash
oc label namespace $NAMESPACE istio-discovery=enabled --overwrite
```

Verify:

```bash
oc get namespace $NAMESPACE --show-labels
```

---

# 4. Deploy the Todo Application

The application consists of three workloads:

```text
                    ┌─────────────┐
                    │     User    │
                    │   Service   │
                    └──────┬──────┘
                           │
                           │
                    ┌──────▼──────┐
                    │     Todo    │
                    │   Service   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │    Redis    │
                    └─────────────┘
```

Create the application configuration:

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: todo-config
  namespace: $NAMESPACE
data:
  API_VERSION: v1
  REDIS_URL: redis://redis:6379/0
  USER_URL: http://user:8080
EOF
```

---

## 5. Deploy Redis

Create the Redis StatefulSet:

```bash
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: $NAMESPACE
  labels:
    app: redis
    app.kubernetes.io/part-of: todo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        version: v1
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        args:
        - --save
        - ""
        - --appendonly
        - "no"
        ports:
        - name: redis
          containerPort: 6379
        livenessProbe:
          exec:
            command:
            - redis-cli
            - ping
        readinessProbe:
          exec:
            command:
            - redis-cli
            - ping
EOF
```

Create the Redis Service:

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: $NAMESPACE
  labels:
    app: redis
spec:
  selector:
    app: redis
  ports:
  - name: redis
    port: 6379
    targetPort: redis
EOF
```

Verify:

```bash
oc get pods,svc -n $NAMESPACE
```

---

# 6. Deploy the User Service

Create the User Deployment:

```bash
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user
  namespace: $NAMESPACE
  labels:
    app: user
    app.kubernetes.io/part-of: todo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: user
  template:
    metadata:
      labels:
        app: user
        version: v1
    spec:
      containers:
      - name: user
        image: quay.io/rh_rh/ocp-todo-user:latest
        imagePullPolicy: Always
        env:
        - name: SERVICE_NAME
          value: user
        envFrom:
        - configMapRef:
            name: todo-config
        ports:
        - name: http
          containerPort: 8080
        livenessProbe:
          httpGet:
            path: /health
            port: http
        readinessProbe:
          httpGet:
            path: /health
            port: http
EOF
```

Create the User Service:

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: user
  namespace: $NAMESPACE
  labels:
    app: user
spec:
  selector:
    app: user
  ports:
  - name: http
    port: 8080
    targetPort: http
EOF
```

Verify:

```bash
oc get deployment,pod,svc -n $NAMESPACE
```

---

# 7. Deploy the Todo Service

Create the Todo Deployment:

```bash
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo
  namespace: $NAMESPACE
  labels:
    app: todo
    app.kubernetes.io/part-of: todo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: todo
  template:
    metadata:
      labels:
        app: todo
        version: v1
    spec:
      containers:
      - name: todo
        image: quay.io/rh_rh/ocp-todo:latest
        imagePullPolicy: Always
        env:
        - name: SERVICE_NAME
          value: todo
        envFrom:
        - configMapRef:
            name: todo-config
        ports:
        - name: http
          containerPort: 8080
        livenessProbe:
          httpGet:
            path: /health
            port: http
        readinessProbe:
          httpGet:
            path: /health
            port: http
EOF
```

Create the Todo Service:

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: todo
  namespace: $NAMESPACE
  labels:
    app: todo
spec:
  selector:
    app: todo
  ports:
  - name: http
    port: 8080
    targetPort: http
EOF
```

Verify all workloads:

```bash
oc get pods,svc -n $NAMESPACE
```

You should have:

```text
redis
todo
user
```

in the `Running` state.

---

# 8. Verify Application Connectivity

Before introducing Service Mesh configuration, verify that the application is running.

Check the Todo application:

```bash
oc logs deployment/todo -n $NAMESPACE
```

Check the User service:

```bash
oc logs deployment/user -n $NAMESPACE
```

You can also test the application from inside the namespace.

For example:

```bash
oc run test-client \
  --image=curlimages/curl \
  --rm -it \
  --restart=Never \
  -n $NAMESPACE \
  -- curl -s http://todo:8080/health
```

The application should return a successful health response.

---

# 9. Configure DestinationRules

DestinationRules define traffic policies for services inside the mesh.

Create a DestinationRule for Redis:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: redis
  namespace: $NAMESPACE
spec:
  host: redis
  subsets:
  - name: v1
    labels:
      version: v1
  trafficPolicy:
    connectionPool:
      tcp:
        connectTimeout: 5s
        maxConnections: 50
    tls:
      mode: ISTIO_MUTUAL
EOF
```

Create a DestinationRule for Todo:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: todo
  namespace: $NAMESPACE
spec:
  host: todo
  subsets:
  - name: v1
    labels:
      version: v1
  trafficPolicy:
    connectionPool:
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
      tcp:
        maxConnections: 100
    outlierDetection:
      baseEjectionTime: 30s
      consecutive5xxErrors: 5
      interval: 10s
      maxEjectionPercent: 50
    tls:
      mode: ISTIO_MUTUAL
EOF
```

Create a DestinationRule for User:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: user
  namespace: $NAMESPACE
spec:
  host: user
  subsets:
  - name: v1
    labels:
      version: v1
  trafficPolicy:
    connectionPool:
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
      tcp:
        maxConnections: 100
    outlierDetection:
      baseEjectionTime: 30s
      consecutive5xxErrors: 5
      interval: 10s
      maxEjectionPercent: 50
    tls:
      mode: ISTIO_MUTUAL
EOF
```

Verify:

```bash
oc get destinationrules -n $NAMESPACE
```

---

# 10. Enable STRICT mTLS

Configure the namespace to use STRICT mTLS:

```bash
cat <<EOF | oc apply -f -
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: $NAMESPACE
spec:
  mtls:
    mode: STRICT
EOF
```

Verify:

```bash
oc get peerauthentication -n $NAMESPACE
```

> **Discussion:**
> What happens to traffic between services when STRICT mTLS is enabled?
>
> How does Istio ensure that the traffic is encrypted and authenticated?

---

# 11. Deploy the Istio Ingress Gateway

Create a dedicated ingress gateway in your application namespace.

```bash
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: istio-ingressgateway
  namespace: $NAMESPACE
  labels:
    app: istio-ingressgateway
    istio: todo-ingressgateway
spec:
  type: ClusterIP
  selector:
    istio: todo-ingressgateway
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8443
  - name: http-envoy-prom
    port: 15090
    targetPort: 15090
EOF
```

Create the gateway Deployment:

```bash
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: istio-ingressgateway
  namespace: $NAMESPACE
  labels:
    app: istio-ingressgateway
    istio: todo-ingressgateway
spec:
  replicas: 1
  selector:
    matchLabels:
      istio: todo-ingressgateway
  template:
    metadata:
      labels:
        app: istio-ingressgateway
        istio: todo-ingressgateway
      annotations:
        inject.istio.io/templates: gateway
        sidecar.istio.io/inject: "true"
        proxy.istio.io/config: |
          gatewayTopology:
            numTrustedProxies: 1
    spec:
      containers:
      - name: istio-proxy
        image: auto
        args:
        - proxy
        - router
        - --domain
        - \$(POD_NAMESPACE).svc.cluster.local
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8443
          name: https
        - containerPort: 15021
          name: status-port
        readinessProbe:
          httpGet:
            path: /healthz/ready
            port: status-port
EOF
```

Verify:

```bash
oc get deployment,pod,svc -n $NAMESPACE
```

---

# 12. Create the Istio Gateway

Create an Istio Gateway that listens for HTTP traffic:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: todo-gateway
  namespace: $NAMESPACE
spec:
  selector:
    istio: todo-ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
EOF
```

Verify:

```bash
oc get gateway -n $NAMESPACE
```

---

# 13. Create the VirtualService

First, determine the hostname that will be used to access your application.

After creating the OpenShift Route in the next step, you will use its hostname here.

Create the VirtualService:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: todo
  namespace: $NAMESPACE
spec:
  gateways:
  - todo-gateway
  hosts:
  - "*"
  http:
  - name: users
    match:
    - uri:
        prefix: /api/users
    route:
    - destination:
        host: user
        port:
          number: 8080
        subset: v1
    timeout: 5s

  - name: todos
    match:
    - uri:
        prefix: /api/todos
    route:
    - destination:
        host: todo
        port:
          number: 8080
        subset: v1
    timeout: 5s

  - name: ui
    route:
    - destination:
        host: todo
        port:
          number: 8080
        subset: v1
EOF
```

> **Note:** Using `hosts: ["*"]` makes the lab configuration independent of the cluster's generated application domain. In a production environment, use an explicit hostname.

Verify:

```bash
oc get virtualservice -n $NAMESPACE
```

---

# 14. Create an OpenShift Route

Expose the Istio ingress gateway through an OpenShift Route:

```bash
cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: todo-ingress
  namespace: $NAMESPACE
spec:
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  to:
    kind: Service
    name: istio-ingressgateway
    weight: 100
EOF
```

Retrieve the application URL:

```bash
oc get route todo-ingress -n $NAMESPACE
```

Or:

```bash
export APP_URL=$(oc get route todo-ingress -n $NAMESPACE -o jsonpath='{.spec.host}')
echo $APP_URL
```

Test the application:

```bash
curl -k https://$APP_URL/
```

Test the Todo API:

```bash
curl -k https://$APP_URL/api/todos
```

Test the User API:

```bash
curl -k https://$APP_URL/api/users
```

---

# 15. Add an EnvoyFilter

An EnvoyFilter can modify the behavior of Envoy proxies.

For this exercise, add custom response headers to traffic passing through the ingress gateway.

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: ingress-lua-headers
  namespace: $NAMESPACE
spec:
  workloadSelector:
    labels:
      istio: todo-ingressgateway
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: GATEWAY
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
            subFilter:
              name: envoy.filters.http.router
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.lua
        typed_config:
          '@type': type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
          defaultSourceCode:
            inlineString: |
              function envoy_on_response(response_handle)
                response_handle:headers():add("x-workshop-mesh", "ossm")
                response_handle:headers():add("x-todo-filter", "lua")
              end
EOF
```

Test the response headers:

```bash
curl -k -I https://$APP_URL/
```

You should see:

```text
x-workshop-mesh: ossm
x-todo-filter: lua
```

---

# 16. Configure Monitoring

OpenShift user-workload monitoring can be used to collect application and Envoy metrics.

## 16.1 Todo ServiceMonitor

```bash
cat <<EOF | oc apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: todo-service-monitor
  namespace: $NAMESPACE
  labels:
    openshift.io/user-monitoring: "true"
spec:
  selector:
    matchLabels:
      app: todo
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
  targetLabels:
  - app
EOF
```

## 16.2 User ServiceMonitor

```bash
cat <<EOF | oc apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: user-service-monitor
  namespace: $NAMESPACE
  labels:
    openshift.io/user-monitoring: "true"
spec:
  selector:
    matchLabels:
      app: user
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
  targetLabels:
  - app
EOF
```

## 16.3 Istio Ingress Gateway ServiceMonitor

```bash
cat <<EOF | oc apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: istio-ingressgateway-service-monitor
  namespace: $NAMESPACE
  labels:
    openshift.io/user-monitoring: "true"
spec:
  selector:
    matchLabels:
      app: istio-ingressgateway
  endpoints:
  - port: http-envoy-prom
    path: /stats/prometheus
    interval: 30s
  targetLabels:
  - app
EOF
```

Verify:

```bash
oc get servicemonitor -n $NAMESPACE
```

---

# 17. Create a PodMonitor for Istio Proxies

Create a PodMonitor to collect Envoy proxy metrics:

```bash
cat <<EOF | oc apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: istio-proxies-monitor
  namespace: $NAMESPACE
  labels:
    openshift.io/user-monitoring: "true"
spec:
  selector:
    matchExpressions:
    - key: istio-prometheus-ignore
      operator: DoesNotExist
  podMetricsEndpoints:
  - interval: 30s
    path: /stats/prometheus
    relabelings:
    - action: keep
      regex: istio-proxy
      sourceLabels:
      - __meta_kubernetes_pod_container_name
    - action: replace
      sourceLabels:
      - __meta_kubernetes_namespace
      targetLabel: namespace
EOF
```

Verify:

```bash
oc get podmonitor -n $NAMESPACE
```

---

# 18. Configure NetworkPolicies

NetworkPolicies control which workloads can communicate with your application namespace.

## Allow traffic from OpenShift Ingress

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-openshift-ingress
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          network.openshift.io/policy-group: ingress
EOF
```

## Allow traffic from Istio System

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-istio-system
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: istio-system
EOF
```

## Allow traffic from Istio CNI

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-istio-cni
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: istio-cni
EOF
```

## Allow traffic from other mesh namespaces

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-mesh-namespaces
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          istio-discovery: enabled
EOF
```

## Allow monitoring traffic

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-user-workload-monitoring
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: openshift-user-workload-monitoring
EOF
```

Verify:

```bash
oc get networkpolicy -n $NAMESPACE
```

---

# 19. Validate the Service Mesh Configuration

Check the major Service Mesh resources:

```bash
oc get gateway,virtualservice,destinationrule,peerauthentication,envoyfilter -n $NAMESPACE
```

You should see:

```text
Gateway
VirtualService
DestinationRule
PeerAuthentication
EnvoyFilter
```

---

# 20. Verify the Workloads

Check all application workloads:

```bash
oc get pods -n $NAMESPACE
```

Expected:

```text
redis-0
todo-xxxxx
user-xxxxx
istio-ingressgateway-xxxxx
```

Check the services:

```bash
oc get svc -n $NAMESPACE
```

Check the route:

```bash
oc get route -n $NAMESPACE
```

---

# 21. Verify Envoy Sidecar Injection

Check the Todo pod:

```bash
oc get pod -l app=todo -n $NAMESPACE
```

Inspect the containers:

```bash
oc get pod -l app=todo -n $NAMESPACE \
  -o jsonpath='{.items[0].spec.containers[*].name}'
```

You should see the application container and the Istio proxy:

```text
todo istio-proxy
```

Repeat for the User service:

```bash
oc get pod -l app=user -n $NAMESPACE \
  -o jsonpath='{.items[0].spec.containers[*].name}'
```

---

# 22. Verify mTLS

Use Istio's configuration tools to inspect the proxy configuration.

If `istioctl` is available:

```bash
istioctl proxy-status
```

Inspect the Todo proxy:

```bash
istioctl proxy-config cluster \
  deployment/todo.$NAMESPACE
```

You can also inspect TLS configuration:

```bash
istioctl proxy-config secret \
  deployment/todo.$NAMESPACE
```

> **Question:**
> What indicates that the workload is participating in the Istio mesh?

---

# 23. Verify Traffic Through the Gateway

Generate several requests:

```bash
for i in {1..10}; do
  curl -sk https://$APP_URL/api/todos
  echo
done
```

Generate traffic to the User service:

```bash
for i in {1..10}; do
  curl -sk https://$APP_URL/api/users
  echo
done
```

Observe the application logs:

```bash
oc logs deployment/todo -n $NAMESPACE
```

```bash
oc logs deployment/user -n $NAMESPACE
```

Observe the ingress gateway logs:

```bash
oc logs deployment/istio-ingressgateway -n $NAMESPACE
```

---

# 24. Observability

If Kiali is available in the environment, open Kiali and locate your namespace.

Look for:

```text
Ingress Gateway
      |
      v
    Todo
      |
      +------> User
      |
      +------> Redis
```

Generate additional traffic while observing the Kiali graph.

```bash
while true; do
  curl -sk https://$APP_URL/api/todos >/dev/null
  curl -sk https://$APP_URL/api/users >/dev/null
  sleep 1
done
```

Stop the loop with:

```text
Ctrl+C
```

---

# 25. Final Validation Checklist

Before completing the lab, verify the following:

* [ ] `$NAMESPACE` points to your assigned namespace.
* [ ] Todo Deployment is running.
* [ ] User Deployment is running.
* [ ] Redis StatefulSet is running.
* [ ] All Services are available.
* [ ] Istio ingress gateway is running.
* [ ] Istio Gateway exists.
* [ ] VirtualService exists.
* [ ] DestinationRules exist for Todo, User, and Redis.
* [ ] STRICT mTLS is configured.
* [ ] OpenShift Route is available.
* [ ] Application is accessible through the Route.
* [ ] EnvoyFilter adds the workshop response headers.
* [ ] ServiceMonitors are configured.
* [ ] PodMonitor is configured.
* [ ] Required NetworkPolicies are configured.
* [ ] Istio proxy is present in the application pods.
* [ ] Application traffic is visible through the Service Mesh.

---

# 26. Useful Troubleshooting Commands

### Check everything in the namespace

```bash
oc get all -n $NAMESPACE
```

### Check Service Mesh resources

```bash
oc get gateway,virtualservice,destinationrule,peerauthentication,envoyfilter -n $NAMESPACE
```

### Check NetworkPolicies

```bash
oc get networkpolicy -n $NAMESPACE
```

### Check pod events

```bash
oc describe pod <pod-name> -n $NAMESPACE
```

### Check application logs

```bash
oc logs deployment/todo -n $NAMESPACE
```

```bash
oc logs deployment/user -n $NAMESPACE
```

### Check ingress gateway logs

```bash
oc logs deployment/istio-ingressgateway -n $NAMESPACE
```

### Check proxy containers

```bash
oc get pods -n $NAMESPACE \
  -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.containers[*].name}{"\n"}{end}'
```

### Check the generated Route

```bash
oc get route todo-ingress -n $NAMESPACE
```

### Test the application

```bash
curl -sk https://$APP_URL/
```

---

# Lab Completion

You have now deployed a microservices application and integrated it with OpenShift Service Mesh.

The resulting architecture is:

```text
                         External Client
                               |
                               | HTTPS
                               v
                    +----------------------+
                    | OpenShift Router     |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    | Istio Ingress Gateway |
                    |      Envoy Proxy      |
                    +----------+-----------+
                               |
                         Istio Gateway
                               |
                       VirtualService
                               |
                +--------------+--------------+
                |                             |
                v                             v
        +---------------+             +---------------+
        |     Todo      |             |     User      |
        |   Envoy + App |<----------->|   Envoy + App |
        +-------+-------+             +---------------+
                |
                | mTLS
                v
        +---------------+
        |     Redis     |
        |   Envoy + DB  |
        +---------------+

                 |
                 v
       +-----------------------+
       | Prometheus / Kiali    |
       | Metrics & Topology    |
       +-----------------------+
```

**Congratulations! You have completed the OpenShift Service Mesh hands-on tasks.**
