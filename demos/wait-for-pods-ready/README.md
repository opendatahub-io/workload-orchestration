# Kueue's Gang Scheduling and WaitForPodsReady Feature Demo

In this demonstration we will showcase Kueue's native Gang Scheduling behavior, and the WaitForPodsReady feature which is enabled by default in RHOAI.


## Demo Recording

To replay the demo locally (requires [asciinema](https://asciinema.org)):

```bash
  asciinema play wait-for-pods-ready-demo.cast
```

[Demo recording](https://asciinema.org/a/710075) (hosted)

## Overview

Kueue's native Gang Scheduling behavior can ensure that a Job is only admitted once all requested compute resource, such as GPUs, are available. This prevents partial execution and optimizes resource utilization.

Moreover, this demo will show how the WaitForPodsReady feature evicts Pods that fail to become ready within the PodsReadyTimeout period which by default is set to 5 minutes. The associated Job will be re-queued after a 60-second delay.

Before running through the demo, we are going to setup our cluster with the following resources:

1. Create a namespace:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    kubernetes.io/metadata.name: demo
  name: demo
```
`oc apply -f resources/namespace.yaml`

2. Create a ClusterQueue resource, noting that we've set the GPU quota to 3:
```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: "cluster-queue"
spec:
  namespaceSelector: {}
  resourceGroups:
  - coveredResources: ["cpu", "memory", "pods", "nvidia.com/gpu"]
    flavors:
    - name: "default-flavor"
      resources:
      - name: "cpu"
        nominalQuota: 10
      - name: "memory"
        nominalQuota: 36Gi
      - name: "pods"
        nominalQuota: 9
      - name: "nvidia.com/gpu"
        nominalQuota: 3 # Max amount of GPUs that can be requested
```
`oc apply -f resources/cluster-queue.yaml`

3. Create a ResourceFlavor resource:
```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: default-flavor
```
`oc apply -f resources/resource-flavor.yaml`

4. Create a LocalQueue resource:
```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: user-queue
  namespace: demo
spec:
  clusterQueue: cluster-queue
```
`oc apply -f resources/local-queue.yaml`

5. For this example, we will also create a Pod that acts as a server, and a Service to expose it:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sample-server
  namespace: demo
  labels:
    app: sample-app
spec:
  containers:
    - name: server
      image: python:3.9-slim
      command: ["python", "-m", "http.server", "80"]
      ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: sample-service
  namespace: demo
spec:
  selector:
    app: sample-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```
`oc apply -f resources/service.yaml`


## Demo
Now that have our server running and accepting connections, we are going to create two Jobs to demonstrate Gang Scheduling and the WaitForPodsReady feature. We must note that the GPU quota is set to 3.

We will create two Jobs that will each request 2 GPUs (a total of 4 GPUs which exceed the quota). We should create both Jobs one after the other:

1. The first Job is setup to deliberately attempt to run an invalid command, causing the Pods to fail.
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  generateName: curl-job-fail-
  namespace: demo
  labels:
    kueue.x-k8s.io/queue-name: user-queue
spec:
  parallelism: 2
  completions: 2
  suspend: true
  template:
    spec:
      containers:
      - name: curl
        image: curlimages:curl
        command: [bad command that doesn't exist] # This command will fail, causing the Pods to fail
        resources:
          requests:
            cpu: 1
            memory: "200Mi"
            nvidia.com/gpu: 1
          limits:
            cpu: 1
            memory: "200Mi"
            nvidia.com/gpu: 1
      restartPolicy: Never
```
`oc apply -f resources/job-fail-curl.yaml`

2. The second Job, once admitted by Kueue, it will run a valid command to curl the Service endpoint, causing the Pods to succeed.
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  generateName: curl-job-success-
  namespace: demo
  labels:
    kueue.x-k8s.io/queue-name: user-queue
spec:
  parallelism: 2
  completions: 2
  suspend: true
  template:
    spec:
      containers:
      - name: curl
        image: curlimages:curl
        command: ["sh", "-c", "sleep 5 && curl http://sample-service"]
        resources:
          requests:
            cpu: 1
            memory: "200Mi"
            nvidia.com/gpu: 1
          limits:
            cpu: 1
            memory: "200Mi"
            nvidia.com/gpu: 1
      restartPolicy: Never
```
`oc apply -f resources/job-success-curl.yaml`

<br>

Run `oc get pods -n demo`:
```
NAME                        READY   STATUS                 RESTARTS   AGE                                                                                                                                                                     
curl-job-fail-mvvw4-bsqhx   0/1     CreateContainerError   0          2m                                                                                                                                                                      
curl-job-fail-mvvw4-wsvv7   0/1     CreateContainerError   0          2m                                                                                                                                                                      
sample-server               1/1     Running                0          74m
```

We can see that even though we created both Jobs, the second Job is not yet admitted and no pods start due to Kueue's native Gang Scheduling behavior.

We can also see that the Pods from the first Job fail to become ready, causing this first Workload to be holding onto GPU and other compute resources indefinitely, and causing resource starvation for other Workloads, such as for the second Job.

Thanks to Kueue's WaitForPodsReady feature, the first Workload will be evicted and eventually re-queued, allowing for the second Workload to be admitted and complete successfully.

<br>

Run `oc get workloads -n demo`:
```
NAME                               QUEUE        RESERVED IN     ADMITTED   FINISHED   AGE                                                                                                                                                     
job-curl-job-fail-mvvw4-fd87f      user-queue   cluster-queue   True                  4m                                                                                                                                                      
job-curl-job-success-mcr8p-8928c   user-queue                                         4m
```

<br>

We will see that after the PodsReadyTimeout period (5 minutes) has passed, the first Workload will be evicted, and the second Workload will be admitted:

```
NAME                               QUEUE        RESERVED IN     ADMITTED   FINISHED   AGE                                                                                                                                                     
job-curl-job-fail-mvvw4-fd87f      user-queue                   False                 5m                                                                                                                                                      
job-curl-job-success-mcr8p-8928c   user-queue   cluster-queue   True                  5m
```

<br>

We can inspect the conditions of the first workload by running i.e.:

`oc get workload job-curl-job-fail-mvvw4-fd87f -n demo -o json | jq '.status.conditions`.

Given the Job had exceeded the PodsReadyTimeout of 5 minutes, the Workload was evicted, allowing for the second Job to be admitted and complete successfully.

<br>

Run `oc get pods -n demo`:
```
NAME                           READY   STATUS      RESTARTS   AGE                                                                                                                                                                             
curl-job-success-mcr8p-6gzsw   0/1     Completed   0          49s                                                                                                                                                                             
curl-job-success-mcr8p-8djzb   0/1     Completed   0          49s                                                                                                                                                                             
sample-server                  1/1     Running     0          77m
```


As we observed in the demo, the second Job was admitted right after the first Job had been evicted by Kueue, and this way avoiding resource starvation and allowing for subsequent Workloads in the queue to be admitted.

By default, Kueue will wait for 5 minutes for the Pods to become ready. If the Pods do not become ready within this time frame, Kueue evicts the Workload and re-queues it after 60 seconds. The time to re-queue a Workload after each consecutive timeout is increased exponentially by a factor of 2. I.e., after approximately 60, 120, 240, ..., 3600 seconds. By default, the backoffLimitCount is set to 5, and the backoffMaxSeconds is set to 3600 seconds. If any of these limits are reached, Kueue will deactivate the Workload.
