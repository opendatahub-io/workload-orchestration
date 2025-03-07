# Kueue GPU Preemption Demo

This repository demonstrates how Kueue preempts low-priority jobs to make room for high-priority jobs, ensuring fair resource allocation across teams in a Kubernetes environment.

## Demo Recording

To replay the demo locally (requires [asciinema](https://asciinema.org)):

```bash
  asciinema play gpu-preemption-demo.cast
```

[Demo recording](https://asciinema.org/a/A46ZADXa9EQkoLxKM7NJD1Gu6) (hosted)

## Overview

This demo showcases Kueue's GPU preemption capabilities in a multi-team scenario:

Team A: Has access to GPUs with high priority<br>
Team B: Shares the cluster but with lower priority<br>
Both teams belong to the same cohort and share CPU/memory quotas<br>
Team A can preempt resources from Team B when needed<br>

In this demonstration:

Team B initially deploys a Job that consumes CPU resources<br>
Team A deploys a high-priority Job requiring 2 GPUs<br>
Kueue automatically preempts Team B's workload to accommodate Team A's request<br>
Resource allocation follows defined priorities and quotas<br>

Implementation

1. Create Team Namespaces

Namespaces logically separate resources for each team.

<table>
<tr>
<th>Team A namespace</th>
<th>Team B namespace</th>
</tr>
<tr>
<td>

```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    kubernetes.io/metadata.name: team-a
  name: team-a
```

</td>
<td>

```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    kubernetes.io/metadata.name: team-b
  name: team-b
```

</td>
</tr>
</table>

2. Apply ResourceFlavors

Set up flavors to distinguish between GPU and non-GPU workloads:

<table>
<tr>
<th>Default ResourceFlavors</th>
<th>GPU ResourceFlavors</th>
</tr>
<tr>
<td>

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: default-flavor
```

</td>
<td>

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: gpu-flavor
```

</td>
</tr>
</table>

3. Configure teams and shared ClusterQueues

Set up the queue hierarchy with appropriate preemption policies:

<table>
<tr>
<th>Team A ClusterQueue</th>
<th>Team B ClusterQueue</th>
</tr>
<tr>
<td>

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: team-a-cq
spec:
  preemption:
    reclaimWithinCohort: Any
    borrowWithinCohort:
      policy: LowerPriority
      maxPriorityThreshold: 100
    withinClusterQueue: Never
  namespaceSelector:
    matchLabels:
      kubernetes.io/metadata.name: team-a
  cohort: team-ab
  resourceGroups:
    - coveredResources:
        - cpu
        - memory
      flavors:
        - name: default-flavor
          resources:
            - name: cpu
              nominalQuota: 0
            - name: memory
              nominalQuota: 0
    - coveredResources:
        - nvidia.com/gpu
      flavors:
        - name: gpu-flavor
          resources:
            - name: nvidia.com/gpu
              nominalQuota: "2"
```

</td>
<td valign="top">

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: team-b-cq
spec:
  cohort: team-ab
  namespaceSelector:
    matchLabels:
      kubernetes.io/metadata.name: team-b
  resourceGroups:
    - coveredResources:
        - nvidia.com/gpu
      flavors:
        - name: gpu-flavor
          resources:
            - name: nvidia.com/gpu
              nominalQuota: "0"
              borrowingLimit: "0"
    - coveredResources:
        - cpu
        - memory
      flavors:
        - name: default-flavor
          resources:
            - name: cpu
              nominalQuota: 0
            - name: memory
              nominalQuota: 0
```

</td>
</tr>
</table>

And a Shared ClusterQueue

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: "shared-cq"
spec:
  preemption:
    reclaimWithinCohort: Any
    borrowWithinCohort:
      policy: LowerPriority
      maxPriorityThreshold: 100
    withinClusterQueue: Never
  namespaceSelector: {} # match all.
  cohort: team-ab
  resourceGroups:
    - coveredResources:
        - cpu
        - memory
      flavors:
        - name: "default-flavor"
          resources:
            - name: "cpu"
              nominalQuota: 10
            - name: "memory"
              nominalQuota: 64Gi
```

4. Create LocalQueues

<table>
<tr>
<th>Team A LocalQueue</th>
<th>Team B LocalQueue</th>
</tr>
<tr>
<td>

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: local-queue
  namespace: team-a
spec:
  clusterQueue: team-a-cq
```

</td>
<td>

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: local-queue
  namespace: team-b
spec:
  clusterQueue: team-b-cq
```

</td>
</tr>
</table>

5. Define Workload Priorities

Higher-priority workloads preempt lower-priority ones.

```yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: WorkloadPriorityClass
metadata:
  name: prod-priority
value: 1000
description: "Priority class for prod jobs"
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: WorkloadPriorityClass
metadata:
  name: dev-priority
value: 100
description: "Priority class for development jobs"
```

6. Deploy Jobs

Deploy Team B's Job first:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: team-b-job
  namespace: team-b
  labels:
    kueue.x-k8s.io/queue-name: local-queue
    kueue.x-k8s.io/priority-class: dev-priority
spec:
  template:
    spec:
      containers:
        - name: app
          image: busybox
          command: ["sleep", "3600"]
          resources:
            requests:
              cpu: "5"
      restartPolicy: Never
```

After deployment: Team B's job starts running, consuming available CPU resources.
Deploy Team A's high-priority job (Triggers Preemption)

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: team-a-job
  namespace: team-a
  labels:
    kueue.x-k8s.io/queue-name: local-queue
    kueue.x-k8s.io/priority-class: prod-priority
spec:
  template:
    spec:
      containers:
        - name: app
          image: busybox
          command: ["sleep", "3600"]
          resources:
            requests:
              cpu: "7"
              nvidia.com/gpu: 2
            limits:
              nvidia.com/gpu: 2
      restartPolicy: Never
```

After deployment: Kueue detects that Team A's job has higher priority and preempts Team B's job by evicting it, allowing Team A's job to use the GPUs and required CPU resources.
This setup ensures that high-priority workloads get necessary resources when required, while maintaining fairness across teams.
