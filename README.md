# OpenShift Basic Hands-On Workshop

A basic hands-on workshop for learning the fundamentals of deploying and managing workloads on **Red Hat OpenShift Container Platform (OCP)**.

This repository contains simple Kubernetes/OpenShift manifests that demonstrate common workload and configuration resources.

## Repository Structure

```text
ocp-overview/
├── basic/
│   ├── configmaps/
│   │   └── todo-cm.yaml
│   ├── daemonsets/
│   │   └── todo-daemonset.yaml
│   ├── deployments/
│   │   └── todo-deployment.yaml
│   ├── pod/
│   │   └── todo-pod.yaml
│   ├── replicasets/
│   │   └── todo-replicaset.yaml
│   └── secrets/
│       └── ...
└── .gitignore
```

The repository currently focuses on the basic Kubernetes workload resources and configuration objects shown above.

## Prerequisites

You will need:

* Access to an OpenShift cluster
* An OpenShift user account with permission to create resources
* `oc` CLI installed
* Access to the container image:

## 1. Login to OCP cluster

Login to the cluster:

```bash
./oc-login.sh <username> <password>
```

Verify the namespace:

```bash
oc project
```

A project in OpenShift provides a logical boundary for your application resources.

## 2. Pod

The simplest workload example is a Kubernetes Pod.

Manifest:

```text
basic/pod/todo-pod.yaml
```

Deploy it:

```bash
oc apply -f basic/pod/todo-pod.yaml
```

Check the Pod:

```bash
oc get pods
```

Get more details:

```bash
oc describe pod todo-java
```

View application logs:

```bash
oc logs todo-java
```

A Pod represents one or more containers running together.

```text
Pod
└── Container
    └── todo-java
```

## 3. ReplicaSet

A ReplicaSet maintains a desired number of Pod replicas.

Manifest:

```text
basic/replicasets/todo-replicaset.yaml
```

Deploy it:

```bash
oc apply -f basic/replicasets/todo-replicaset.yaml
```

Check the ReplicaSet:

```bash
oc get replicasets
```

Check the Pods:

```bash
oc get pods
```

For example, with two replicas:

```text
ReplicaSet
├── todo-java Pod
└── todo-java Pod
```

If one Pod is deleted, the ReplicaSet automatically creates a replacement.

```bash
oc delete pod <pod-name>
```

Then:

```bash
oc get pods
```

## 4. Deployment

A Deployment is the recommended way to manage most application workloads on OpenShift.

Manifest:

```text
basic/deployments/todo-deployment.yaml
```

Deploy it:

```bash
oc apply -f basic/deployments/todo-deployment.yaml
```

Check the Deployment:

```bash
oc get deployment
```

Check the ReplicaSet:

```bash
oc get replicasets
```

Check the Pods:

```bash
oc get pods
```

The relationship is:

```text
Deployment
    |
    v
ReplicaSet
    |
    +---- Pod
    +---- Pod
```

A Deployment provides additional capabilities such as:

* Scaling
* Rolling updates
* Rollback
* Revision history
* ReplicaSet management

Check rollout status:

```bash
oc rollout status deployment/todo-java
```

View rollout history:

```bash
oc rollout history deployment/todo-java
```

## 5. DaemonSet

A DaemonSet ensures that a Pod runs on each eligible node.

Manifest:

```text
basic/daemonsets/todo-daemonset.yaml
```

Deploy it:

```bash
oc apply -f basic/daemonsets/todo-daemonset.yaml
```

Check the DaemonSet:

```bash
oc get daemonset
```

Check the Pods:

```bash
oc get pods -o wide
```

Unlike a Deployment, you don't specify a replica count.

For example:

```text
Node 1 ── todo Pod
Node 2 ── todo Pod
Node 3 ── todo Pod
```

DaemonSets are commonly used for node-level services such as logging, monitoring, security, and networking agents.

## 6. ConfigMap

ConfigMaps allow configuration to be separated from the application container image.

Manifest:

```text
basic/configmaps/todo-cm.yaml
```

Create the ConfigMap:

```bash
oc apply -f basic/configmaps/todo-cm.yaml
```

View it:

```bash
oc get configmap
```

View the contents:

```bash
oc describe configmap todo-java-configmap
```

A ConfigMap can be consumed by a Pod as:

* Environment variables
* Configuration files
* Command-line arguments

Example:

```yaml
env:
  - name: TZ
    valueFrom:
      configMapKeyRef:
        name: todo-java-configmap
        key: timezone
```

## 7. Secret

Secrets are used to store sensitive configuration such as:

* Usernames
* Passwords
* Tokens
* Credentials
* Certificates

Manifest:

```text
basic/secrets/
```

Create the Secret:

```bash
oc apply -f basic/secrets/
```

List Secrets:

```bash
oc get secrets
```

Inspect the Secret metadata:

```bash
oc describe secret todo-java-secret
```

Secrets can be injected into a Pod using `secretKeyRef`:

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: todo-java-secret
        key: DB_PASSWORD
```

> **Important:** Do not commit real production credentials or passwords to Git. Use appropriate secret-management mechanisms for production environments.

## 8. Deployment vs ReplicaSet vs DaemonSet

A useful way to understand the resources in this workshop is:

```text
                    Deployment
                        |
                        v
                   ReplicaSet
                        |
             +----------+----------+
             |          |          |
            Pod        Pod        Pod


                    DaemonSet
                        |
          +-------------+-------------+
          |             |             |
        Node 1        Node 2        Node 3
          |             |             |
         Pod           Pod           Pod
```

### Deployment

Use when you want to run and manage an application.

```text
Application workload
        ↓
   Deployment
```

### ReplicaSet

Use to maintain a specified number of Pod replicas.

```text
Desired replicas = 3
        ↓
   ReplicaSet
        ↓
  3 × Pods
```

Normally, you let a Deployment manage the ReplicaSet rather than creating ReplicaSets directly.

### DaemonSet

Use when you need one Pod on each eligible node.

```text
Node 1 → Pod
Node 2 → Pod
Node 3 → Pod
```

## 9. Useful OpenShift Commands

### Resources

```bash
oc get pods
oc get deployments
oc get replicasets
oc get daemonsets
oc get services
oc get configmaps
oc get secrets
```

### Detailed information

```bash
oc describe pod <pod-name>
oc describe deployment <deployment-name>
oc describe service <service-name>
```

### Logs

```bash
oc logs <pod-name>
```

Follow logs:

```bash
oc logs -f <pod-name>
```

### Execute commands inside a Pod

```bash
oc rsh <pod-name>
```

### Scaling

```bash
oc scale deployment todo-java --replicas=3
```

Verify:

```bash
oc get pods
```

### Delete resources

```bash
oc delete -f basic/deployments/todo-deployment.yaml
```

## OpenShift CLI – Discovering Available Resources

The OpenShift CLI (`oc`) provides several commands for discovering the resources and API capabilities available on your cluster.

### List All Available Resources

Use `oc api-resources` to display the API resources supported by the OpenShift cluster:

```bash
oc api-resources
```

Example:

```text
NAME                SHORTNAMES   APIVERSION                    NAMESPACED   KIND
pods                po           v1                            true         Pod
services            svc          v1                            true         Service
configmaps           cm           v1                            true         ConfigMap
secrets                           v1                            true         Secret
deployments          deploy       apps/v1                       true         Deployment
replicasets          rs           apps/v1                       true         ReplicaSet
daemonsets            ds           apps/v1                       true         DaemonSet
routes                            route.openshift.io/v1           true         Route
ingresses             ing         networking.k8s.io/v1           true         Ingress
...
```

The exact list depends on the OpenShift version and the operators/API extensions installed on the cluster.

### Display More Information

Use `-o wide` to display additional information:

```bash
oc api-resources -o wide
```

### Sort Resources

Sort the resources alphabetically:

```bash
oc api-resources --sort-by=name
```

### List Only Namespaced Resources

Most application resources are namespaced:

```bash
oc api-resources --namespaced=true
```

For example:

```text
pods
services
configmaps
secrets
deployments
replicasets
daemonsets
routes
```

### List Cluster-Scoped Resources

Some resources are not associated with a namespace:

```bash
oc api-resources --namespaced=false
```

Examples include resources such as:

```text
nodes
namespaces
persistentvolumes
clusterroles
clusterrolebindings
```

### List Resources in a Specific API Group

OpenShift and Kubernetes organize resources into API groups.

For example, to see resources in the RBAC API group:

```bash
oc api-resources --api-group=rbac.authorization.k8s.io
```

You can also check the API versions supported by the cluster:

```bash
oc api-versions
```

### Get Information About a Resource

Once you know the resource type, use `oc explain` to explore its schema:

```bash
oc explain deployment
```

For a specific field:

```bash
oc explain deployment.spec
```

For example:

```bash
oc explain deployment.spec.replicas
```

This is particularly useful when creating Kubernetes/OpenShift YAML manifests because it lets you inspect the resource structure directly from the connected cluster.

### Get Resources

Use `oc get` to list resources:

```bash
oc get pods
oc get deployments
oc get services
oc get configmaps
oc get secrets
oc get routes
```

You can also use the resource short names:

```bash
oc get po
oc get deploy
oc get svc
oc get cm
oc get rs
oc get ds
```

### Get All Common Application Resources

A useful command during the workshop is:

```bash
oc get all
```

This displays the common application resources in the current project.

You can also specify a namespace/project:

```bash
oc get all -n todo-workshop
```

### Quick Reference

| Command                                | Purpose                                    |
| -------------------------------------- | ------------------------------------------ |
| `oc api-resources`                     | List resources supported by the cluster    |
| `oc api-resources -o wide`             | List resources with additional information |
| `oc api-resources --namespaced=true`   | List namespaced resources                  |
| `oc api-resources --namespaced=false`  | List cluster-scoped resources              |
| `oc api-resources --api-group=<group>` | List resources in an API group             |
| `oc api-versions`                      | List supported API versions                |
| `oc explain <resource>`                | Show resource documentation/schema         |
| `oc get <resource>`                    | List resources                             |
| `oc get all`                           | List common application resources          |
| `oc describe <resource>`               | Show detailed resource information         |

> **Tip:** When you're unsure whether a resource exists on your OpenShift cluster, start with `oc api-resources`. When you're unsure how to construct its YAML, use `oc explain`.


## 10. Suggested Workshop Flow

For a basic OpenShift introduction, the recommended learning sequence is:

```text
Namespace / Project
        ↓
Pod
        ↓
ReplicaSet
        ↓
Deployment
        ↓
DaemonSet
        ↓
ConfigMap
        ↓
Secret
        ↓
Service
        ↓
Route / Ingress
```

This progression introduces the core concepts before moving toward more advanced OpenShift capabilities.

## Next Steps

After completing the basic exercises, the workshop can be extended with:

* Services
* OpenShift Routes
* Kubernetes Ingress
* Resource Requests and Limits
* Liveness and Readiness Probes
* Horizontal Pod Autoscaler
* PodDisruptionBudget
* NetworkPolicy
* Service Accounts
* RBAC
* Persistent Volumes
* OpenShift Service Mesh
* OpenShift GitOps / Argo CD

## Repository

Source repository:

[ocp-overview](https://github.com/secangkirkopipanas/ocp-overview)

---

**Happy OpenShift learning! 🚀**
