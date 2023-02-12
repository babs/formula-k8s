# k8s

Formula to install kubernetes cluster, control plane and worker.

Goal of this formula is to bootstrap a kubernetes cluster with a given version for the first CP then be able to add masters and workers taking the version from the main CP.

This way, the cluster can have its own lifecycle and still be able to grow using this formula.

# Note about pillar

Along with a proper pillar, this formula requires 3 ssh keys that can be generated using `tools/genkey.sh` .

Assuming a cluster is named `k8s01`, uses `k8s01-mXX` for master and `k8s01-wXX` for worker as naming convention and has the following pillar tree:

```
k8s01
├── cluster.sls         # Cluster definition, see pillar.example
├── k8s_ssh_install.sls # Generated key pair for pki propagation between CP
├── k8s_ssh_join.sls    # Generated key pair for getting join token
└── k8s_ssh_version.sls # Generated key pair for getting version
```

Here is what a pillar's `top.sls` can look like:

```yaml
base:
  'k8s01-m\d+':
    - match: pcre
    - k8s01.k8s_ssh_install
  'k8s01-[mw]\d+':
    - match: pcre
    - k8s01.cluster
    - k8s01.k8s_ssh_join
    - k8s01.k8s_ssh_version
```


# Available states

    k8s

## `k8s`

Deploy kubernetes on the target node. Based on the `minion_id` and the pillar, proper role will be assigned.


`salt/top.sls` example:

```yaml
base:
  'k8s01-[mw]\d+':
    - match: pcre
    - k8s
```