# Workshop Task: Autoscale the Java Application with HPA

## Objective

Configure **Horizontal Pod Autoscaling (HPA)** for the existing Java application.

The application is deployed using:

```text
quay.io/rh_rh/todo-java:latest
```

Your task is to configure HPA so that OpenShift automatically scales the `todo-deployment` based on CPU utilization.

### Requirements

| Requirement      | Value             |
| ---------------- | ----------------- |
| Deployment       | `todo-deployment` |
| Minimum replicas | `2`               |
| Maximum replicas | `4`               |
| CPU target       | `70%`             |
| Scaling resource | CPU               |
| HPA name         | `todo-deployment` |

---

## Task 1 — Check the Existing Deployment

Verify the Deployment:

```bash
oc get deployment todo-deployment
```

Verify the Pods:

```bash
oc get pods -l app=todo-deployment
```

You should have at least two running Pods.

Also check the CPU and memory configuration:

```bash
oc describe deployment todo-deployment
```

Make sure the Java container has a CPU request.

For example:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

> HPA requires a CPU request to calculate CPU utilization as a percentage.

---

## Task 2 — Create the HPA

Create:

```text
todo-deployment-hpa.yaml
```

Configure an HPA with:

* Target Deployment: `todo-deployment`
* Minimum replicas: `2`
* Maximum replicas: `4`
* Target CPU utilization: `70%`

### Hint

Use:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
```

and:

```yaml
scaleTargetRef:
  apiVersion: apps/v1
  kind: Deployment
  name: todo-deployment
```

---

## Task 3 — Apply the HPA

Apply your manifest:

```bash
oc apply -f todo-deployment-hpa.yaml
```

Check the HPA:

```bash
oc get hpa
```

Expected:

```text
NAME              REFERENCE                     TARGETS   MINPODS   MAXPODS   REPLICAS
todo-deployment   Deployment/todo-deployment    5%/70%    2         4         2
```

The exact CPU utilization will depend on the current workload.

---

## Task 4 — Monitor the Application

Open a second terminal and monitor CPU:

```bash
oc adm top pods
```

Watch the HPA:

```bash
oc get hpa todo-deployment -w
```

And watch the Pods:

```bash
oc get pods -w
```

---

## Task 5 — Generate CPU Load Using Java

Because `todo-deployment` is a Java application, use `$JAVA_HOME/bin/jshell` inside one of the Java Pods to generate CPU load.

Find a Pod:

```bash
oc get pods -l app=todo-deployment
```

Enter the Pod:

```bash
oc rsh <todo-pod>
```

Start JShell:

```bash
$JAVA_HOME/bin/jshell
```

Check the available processors:

```java
Runtime.getRuntime().availableProcessors()
```

Then generate CPU load:

```java
for (int i = 0; i < Runtime.getRuntime().availableProcessors(); i++) {
    new Thread(() -> {
        while (true) {
            double x = Math.random();

            for (int j = 0; j < 100000; j++) {
                x = Math.sin(x) * Math.cos(x)
                    + Math.sqrt(Math.abs(x));
            }
        }
    }).start();
}
```

This creates CPU-intensive Java threads.

---

## Task 6 — Observe HPA Scaling

From another terminal:

```bash
oc adm top pods
```

You should see CPU utilization increase.

Then:

```bash
oc get hpa todo-deployment -w
```

As the average CPU utilization exceeds the target of **70%**, the HPA should increase the number of replicas.

For example:

```text
Initial:

todo-deployment
├── Pod 1
└── Pod 2

        CPU increases
              │
              ▼
             HPA
              │
         CPU > 70%
              │
              ▼
        Scale Deployment
              │
              ▼

todo-deployment
├── Pod 1
├── Pod 2
├── Pod 3
└── Pod 4
```

The Deployment should scale up to a maximum of **4 replicas**.

---

## Task 7 — Stop the CPU Load

Stop the JShell session:

```text
Ctrl+C
```

If necessary, exit the Pod:

```bash
exit
```

Continue watching:

```bash
oc get hpa todo-deployment -w
```

After CPU utilization decreases and the HPA's stabilization period passes, the Deployment should scale back down.

It must not go below:

```text
2 replicas
```

---

## Task 8 — Verify the Application

Check:

```bash
oc get deployment todo-deployment
```

```bash
oc get pods -l app=todo-deployment
```

If the application is already exposed through a Service and Route, verify that it remains accessible while the number of Pods changes.

The Service and Route do not need to be modified when HPA adds or removes Pods.

---

## Expected Architecture

```text
                         HPA
                          │
                 CPU utilization > 70%
                          │
                          ▼
                  todo-deployment
                          │
                      ReplicaSet
                          │
             ┌────────────┼────────────┐
             ▼            ▼            ▼
          Pod 1         Pod 2        Pod 3
          Java           Java          Java
                                        │
                                        ▼
                                      Pod 4
                                      Java
```

Application traffic continues to flow through the existing Service:

```text
                       External Client
                              │
                              ▼
                         OpenShift
                           Route
                              │
                              ▼
                          Service
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
           Java Pod 1      Java Pod 2      Java Pod 3
                             
                              ▲
                              │
                             HPA
                              │
                         CPU > 70%
```

---

## Challenge

Modify the HPA configuration to:

```text
Minimum replicas: 1
Maximum replicas: 4
CPU target:       50%
```

Observe the difference in scaling behavior.

Then restore:

```text
Minimum replicas: 2
Maximum replicas: 4
CPU target:       70%
```

---

## Learning Objectives

After completing this exercise, you should understand:

* How HPA targets a Deployment
* How CPU utilization drives automatic scaling
* Why CPU requests are required for CPU-based HPA
* How a Java workload can generate CPU pressure
* How HPA increases replicas when demand increases
* How HPA scales back down when demand decreases
* How Services continue routing traffic while Pods are dynamically created or removed
* The difference between manual scaling and automatic scaling
