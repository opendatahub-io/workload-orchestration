# ResourceFlavor Taints and Tolerations in RHOAI

In this demonstration we will be showcasing how to set Taints and Tolerations to Kueue ResourceFlavors for ensuring workloads are run on specific hardware.

## Demo Recording

To replay the demo locally (requires [asciinema](https://asciinema.org/)):

```bash
  asciinema play resource-flavor-t-and-t.cast
```

[Demo Recording](https://asciinema.org/a/mqfILpE8HwsjMVKr04zk10u3S)(hosted)

## Overview

Kueue affords for two modes of ResourceFlavor Taints and Tolerations. 

* Mode 1: A ResourceFlavor has a Toleration set and will apply the Toleration to the workload using it's ClusterQueue.
* Mode 2: A ResourceFlavor has a Taint set and users can manually add the Toleration to the workload for ensuring scheduling on specific hardware.

The following example assumes: 

* The user has 3 `g4dn.2xlarge` and 3 `g5.2xlarge` instances with the `g4dn.2xlarge` having Nvidia Tesla T4 GPUs and the `g5.2xlarge` having Nvidia A10G GPUs.
* RHOAI installed with Kueue set to `Managed` in the DataScienceCluster.

Before trying either mode of ResourceFlavor Tainting/Tolerating we must ensure that the namespace `team-a` exists:
``` yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
```
`oc apply -f resources/namespace.yaml`

We must also ensure all Nodes are appropriately Tainted:
```bash
oc adm taint nodes -l node.kubernetes.io/instance-type=g4dn.2xlarge nvidia-t4="true":NoSchedule # Will Taint g4dn.2xlarge Nodes 
oc adm taint nodes -l node.kubernetes.io/instance-type=g5.2xlarge nvidia-a10g="true":NoSchedule # Will Taint g5.2xlarge Nodes
```

### Mode 1: Automatic Workload Toleration
For this mode we require 2 separate ResourceFlavors that have Tolerations for the A10G and T4 Nodes.

<table>
<tr>
<th>A10G Tolerating ResourceFlavor</th>
<th>T4 Tolerating ResourceFlavor</th>
</tr>
<tr>
<td>

<!-- Generated by 'make update-readme'. DO NOT EDIT. -->
<!-- YAML-START: demos/resourceflavour-taints-and-tolerations/resources/kueue-resources-tolerate-rf.yaml[1] -->
```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: "nvidia-a10g-rf"
spec:
  nodeLabels:
    node.kubernetes.io/instance-type: g5.2xlarge
  tolerations:
  - key: "nvidia-a10g"
    operator: "Exists"
    effect: "NoSchedule"
```
<!-- YAML-END -->

</td>
<td>

<!-- Generated by 'make update-readme'. DO NOT EDIT. -->
<!-- YAML-START: demos/resourceflavour-taints-and-tolerations/resources/kueue-resources-tolerate-rf.yaml[2] -->
```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: "nvidia-t4-rf"
spec:
  nodeLabels:
    node.kubernetes.io/instance-type: g4dn.2xlarge
  tolerations:
  - key: "nvidia-t4"
    operator: "Exists"
    effect: "NoSchedule"
```
<!-- YAML-END -->

</td>
</tr>
</table>

The full file including ClusterQueue, LocalQueue setup can be found [here](resources/kueue-resources-tolerate-rf.yaml) and applied to the cluster with:
```bash
oc apply -f resources/kueue-resources-tolerate-rf.yaml
```

After applying the Kueue resources we can now apply the batch Job resource.

<!-- Generated by 'make update-readme'. DO NOT EDIT. -->
<!-- YAML-START: demos/resourceflavour-taints-and-tolerations/resources/job.yaml -->
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  generateName: sample-job-
  namespace: team-a
  labels:
    kueue.x-k8s.io/queue-name: user-queue
spec:
  parallelism: 6
  completions: 3
  suspend: true
  template:
    spec:
      containers:
      - name: dummy-job
        image: gcr.io/k8s-staging-perf-tests/sleep:v0.1.0
        args: ["30s"]
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
<!-- YAML-END -->
`oc create -f resources/job.yaml`

The Job's Pods should be scheduled on either the A10G or T4 Nodes. When inspecting the Pods you can see that a Toleration for either Node has been appended by Kueue with:
```bash
oc describe pod -n team-a <pod-name>
```

### Mode 2: Tainted ResourceFlavor
For this mode we require 2 separate ResourceFlavors that have Taints for the A10G and T4 Nodes.

<table>
<tr>
<th>A10G Tainted ResourceFlavor</th>
<th>T4 Tainted ResourceFlavor</th>
</tr>
<tr>
<td>

<!-- Generated by 'make update-readme'. DO NOT EDIT. -->
<!-- YAML-START: demos/resourceflavour-taints-and-tolerations/resources/kueue-resources-tainted-rf.yaml[1] -->
```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: "nvidia-a10g-rf"
spec:
  nodeLabels:
    node.kubernetes.io/instance-type: g5.2xlarge
  nodeTaints:
  - effect: NoSchedule
    key: "nvidia-a10g"
    value: "true"
```
<!-- YAML-END -->

</td>
<td>

<!-- Generated by 'make update-readme'. DO NOT EDIT. -->
<!-- YAML-START: demos/resourceflavour-taints-and-tolerations/resources/kueue-resources-tainted-rf.yaml[2] -->
```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: "nvidia-t4-rf"
spec:
  nodeLabels:
    node.kubernetes.io/instance-type: g4dn.2xlarge
  nodeTaints:
  - effect: NoSchedule
    key: "nvidia-t4"
    value: "true"
```
<!-- YAML-END -->

</td>
</tr>
</table>

The full file including ClusterQueue, LocalQueue setup can be found [here](resources/kueue-resources-tainted-rf.yaml) and applied to the cluster with:<br>
```bash
oc apply -f resources/kueue-resources-tainted-rf.yaml
```

After applying the Kueue resources we can now apply the batch Job resource with the `nvidia-a10g` Toleration.

<!-- Generated by 'make update-readme'. DO NOT EDIT. -->
<!-- YAML-START: demos/resourceflavour-taints-and-tolerations/resources/job-a10g-tolerating.yaml -->
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  generateName: sample-job-
  namespace: team-a
  labels:
    kueue.x-k8s.io/queue-name: user-queue
spec:
  parallelism: 3
  completions: 3
  suspend: true
  template:
    spec:
      containers:
      - name: dummy-job
        image: gcr.io/k8s-staging-perf-tests/sleep:v0.1.0
        args: ["30s"]
        resources:
          requests:
            cpu: 1
            memory: "200Mi"
            nvidia.com/gpu: 1
          limits:
            cpu: 1
            memory: "200Mi"
            nvidia.com/gpu: 1
      tolerations:
        - key: "nvidia-a10g"
          operator: "Exists"
          effect: "NoSchedule"
      restartPolicy: Never
```
<!-- YAML-END -->
`oc create -f resources/job-a10g-tolerating.yaml`

The Pods should only be scheduled on the Node with the A10G GPUs.
You can observe the Node Labels on the Pods by using:
```bash
oc describe pod -n team-a <pod-name>
```
