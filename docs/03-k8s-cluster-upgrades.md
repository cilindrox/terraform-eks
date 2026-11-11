# Upgrading Kubernetes Versions

Cluster control plane and node groups can be upgraded via the
`kubernetes_version` variable.

Addons can be upgraded individually either by passing the addon version on the
`addons` map, or by planning/refreshing the state after upgrading the control
plane.

To update an existing cluster's Kubernetes version, simply update the
`kubernetes_version` value, eg:

```diff
module "eks" {
  # ...

  name = local.cluster_name

-  kubernetes_version = "1.37"
+  kubernetes_version = "1.38"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # ...
}
```

Alternatively, update the `local.kubernetes_version` variable, eg:

```diff
locals {
  # ...

-  kubernetes_version = "1.37"
+  kubernetes_version = "1.38"

}
```

Keep in mind that you will need to pin any node groups to the previous version
to avoid a simultaneous upgrade. See the following section for details.

## Upgrading Node Groups

Node groups can be updated independently of the control plane by overriding the
`kubernetes_version` value on any given node definition.

Although it is possible to upgrade the data plane (nodes) at the same time as
the control plane, it is [highly recommended][update-k8s] to do it on a separate
`plan/apply` stage, eg:

```diff
locals {
  # ...

-  kubernetes_version = "1.37"
+  kubernetes_version = "1.38"

}

module "eks" {
  # ..

  name = local.cluster_name

  kubernetes_version = local.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    my-node = {
+     kubernetes_version = "1.37"

      update_config = {
        max_unavailable_percentage = 10
      }

      # ...

    }
  }

  # ...
}
```

The example above pins the `my-node` node group to the current
`kubernetes_version` and upgrades the control plane. Once the control plane has
been verified, we can proceed with the node group upgrade, eg:

```diff
module "eks" {
  # ...

  name = local.cluster_name

  kubernetes_version = "1.38"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    my-node = {
-     kubernetes_version = "1.37"
+     kubernetes_version = "1.38"

      update_config = {
        max_unavailable_percentage = 10
      }

      # ...

    }
  }

  # ...
}
```

Alternatively, you can remove the `kubernetes_version = "1.37"` line entirely
and rely on the cluster's configured version for the upgrade.

[update-k8s]: https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html
