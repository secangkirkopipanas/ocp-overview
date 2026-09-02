# Workshop Task: Deploy NGINX with 2 Replicas

## Objective

Deploy an NGINX application on OpenShift using:

```text
registry.access.redhat.com/ubi9/nginx-120:9.8-1787720640
```

The application must:

* Run **2 replicas**
* Be managed by a **Deployment**
* Be exposed internally using a **Service**
* Be accessible externally using an **OpenShift Route**
* Use HTTP port **8080**
* Use **edge TLS termination**
* Redirect HTTP traffic to HTTPS

---

## Task 1 — Create the Deployment

Create a Deployment named:

```text
nginx
```

Requirements:

| Requirement     | Value                                        |
| --------------- | -------------------------------------------- |
| Deployment name | `nginx`                                      |
| Image           | `registry.access.redhat.com/hi/nginx:latest` |
| Replicas        | `2`                                          |
| Container port  | `8080`                                       |

Verify:

```bash
oc get deployment
```

Expected:

```text
NAME    READY   UP-TO-DATE   AVAILABLE
nginx   2/2     2            2
```

Verify the Pods:

```bash
oc get pods -o wide
```

You should see two running NGINX Pods.

---

## Task 2 — Create the Service

Create a Service named:

```text
nginx
```

The Service must:

* Select the NGINX Pods
* Expose port `8080`
* Forward traffic to container port `8080`

Verify:

```bash
oc get service
```

Check the Service endpoints:

```bash
oc get endpoints nginx
```

You should see both NGINX Pod IP addresses.

---

## Task 3 — Create the OpenShift Route

Create an OpenShift Route named:

```text
nginx
```

The Route must:

* Point to the `nginx` Service
* Use target port `8080`
* Use **edge TLS termination**
* Redirect HTTP traffic to HTTPS

Verify:

```bash
oc get route
```

Get the Route hostname:

```bash
oc get route nginx
```

Access the application using:

```text
https://<route-hostname>
```

You should see the NGINX welcome page.

---

## Task 4 — Verify the Architecture

Your final architecture should look like:

```text
                         Internet
                            │
                            │ HTTPS
                            ▼
                    OpenShift Route
                          nginx
                            │
                            │ HTTP :8080
                            ▼
                    Service: nginx
                            │
                 ┌──────────┴──────────┐
                 │                     │
                 ▼                     ▼
             NGINX Pod 1          NGINX Pod 2
                :8080                 :8080
```

Check all resources:

```bash
oc get deployment
oc get pods
oc get service
oc get route
```

Or:

```bash
oc get all
```

---

## Task 5 — Verify Service Endpoints

Check the Service:

```bash
oc describe service nginx
```

Look for the **Endpoints** section.

You should see two endpoints:

```text
Endpoints: <pod-ip-1>:8080,<pod-ip-2>:8080
```

This demonstrates how the Service distributes traffic across the two NGINX Pods.

---

## Task 6 — Test External Access

Get the Route URL:

```bash
oc get route nginx \
  -o jsonpath='https://{.spec.host}{"\n"}'
```

Test it from the command line:

```bash
curl -k https://$(oc get route nginx -o jsonpath='{.spec.host}')
```

You should receive the NGINX HTTP response.

You can also open the Route URL in a browser.

---

## Bonus Challenge — Scale the Application

Scale the Deployment from 2 to 3 replicas:

```bash
oc scale deployment nginx --replicas=3
```

Verify:

```bash
oc get pods
```

You should now have three NGINX Pods.

No changes should be required to the Service or Route.

```text
                         Route
                           │
                           ▼
                        Service
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
            Pod 1        Pod 2        Pod 3
           NGINX        NGINX        NGINX
```

---

## Challenge — Create the Manifests Yourself

Without looking at a solution, create these three files:

```text
nginx-deployment.yaml
nginx-service.yaml
nginx-route.yaml
```

Deploy them:

```bash
oc apply -f nginx-deployment.yaml
oc apply -f nginx-service.yaml
oc apply -f nginx-route.yaml
```

Verify:

```bash
oc get all
```

Finally, access the application through the OpenShift Route.

---

## Expected Result

```text
Deployment
    │
    ├── ReplicaSet
    │      ├── NGINX Pod
    │      └── NGINX Pod
    │
    ▼
Service
    │
    ▼
OpenShift Route
    │
    ▼
External HTTPS Access
```

## Learning Objectives

After completing this exercise, you should understand:

* How to deploy NGINX using a Deployment
* How to run multiple replicas
* How a ReplicaSet is created and managed by a Deployment
* How a Service provides stable access to Pods
* How an OpenShift Route exposes an application externally
* How edge TLS termination works
* How HTTP-to-HTTPS redirection works
* How scaling a Deployment affects the underlying Pods
