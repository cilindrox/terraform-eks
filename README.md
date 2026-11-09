# Terraform EKS Cluster

This is an example implementation of an EKS cluster using infrastructure-as-code
(Iac) with [Terraform] and following [AWS' best-practices][eks-best-practices]
recommendations.

## Getting started

You will need a set of IAM account credentials with the appropriate permissions.

Provision the default Terraform state bucket on the account via:

```bash
make bootstrap
```

This will `init` and `plan` the [S3 bucket][tf-s3] creation under the
`bootstrap` directory. This bucket is used for storing each individual
environment's [Terraform state][tf-state].

Apply the changes via:

```bash
terraform -chdir=bootstrap apply
```

These steps are required for initial bucket creation and in case of disaster
recovery.

### Accessing the Kubernetes Cluster

The current implementation uses a private EC2 bastion host, accessible only via
AWS Systems Manager (SSM) Session Manager for securely accessing the cluster's
private endpoint.

The bastion host is provisioned via a [custom terraform
module](./modules/bastion-host).

An alternative to the bastion deployment would be restricting the endpoint's
public access to an IP or CIDR controlled by the managing teams, such as a VPN,
eg:

```diff
module "eks" {
+  endpoint_public_access       = true
+  endpoint_public_access_cidrs = ["10.5.4.3/32"] # VPN IP
}
```

## Repo Structure

Repo structure follows the AWS Organizational Unit structure, where `acme` is
the default root account.

Each environment is then split in subfolders according to the following pattern:

```text
org-root/$ENVIRONMENT/$REGION/$COMPONENT
```

This allows for a clean separation of concerns between remote states and
contains the blast radius in case of problems.

## Upgrading Kubernetes Versions

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

### Upgrading Node Groups

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

## VPC and Subnet Requirements

This repo follows the EKS VPC [requirements and
considerations][vpc-requirements] for the ["Public + Private
subnets"][vpc-subnets] recommended architecture.

### Considerations

The default setup uses an AWS managed NAT Gateway. If egress costs need to be
prioritized, then a community project such as fck-nat can be leveraged instead.

The following is an example:

```hcl
# network.tf

locals {
  # ..

  # VPC module lacks a way of linking subnets to their routing table, requiring
  # this additional map.
  zone_private_route_table = {
    for idx, subnet in module.vpc.private_subnet_objects :
    subnet.availability_zone => module.vpc.private_route_table_ids[idx]
  }
}

#...

data "aws_ami" "fck_nat" {
  most_recent      = true
  owners           = ["568608671756"]

  filter {
    name   = "name"
    values = ["fck*"]
  }
}

module "nat_gw" {
  source = "git::https://github.com/RaJiska/terraform-aws-fck-nat.git?ref=9b991ddf8e61f8834242b33f8eccae3afd57bc4e" # v1.6.1

  for_each = { for s in module.vpc.public_subnet_objects : s.id => s }

  name                 = "${local.nat_gw_name}-${each.value.availability_zone}"
  ami_id               = data.aws_ami.fck_nat.id
  vpc_id               = module.vpc.vpc_id
  subnet_id            = each.key
  ha_mode              = true
  use_cloudwatch_agent = true
  use_ssh              = false

  # ref: https://fck-nat.dev/stable/choosing_an_instance_size/
  instance_type = "t4g.nano"

  eip_allocation_ids = [aws_eip.nat_gw[each.value.availability_zone].id]

  update_route_tables = true
  route_tables_ids = {
    private = one([for az in local.zone_private_route_table[each.value.availability_zone] : az])
  }

  tags = {
    Name    = "${local.nat_gw_name}-${each.value.availability_zone}"
    Role    = "nat-gw"
    Cluster = local.cluster_name
  }
}
```

and then, disable the NAT GW:

```diff
# network .tf
  module "vpc" {
  # ...

-   enable_nat_gateway  = true
+   enable_nat_gateway  = false
-   single_nat_gateway  = false
-   reuse_nat_ips       = true
-   external_nat_ip_ids = [for az in local.azs : aws_eip.nat[az].id]

  }
```

[Terraform]: https://www.terraform.io/
[eks-best-practices]: https://docs.aws.amazon.com/eks/latest/best-practices/introduction.html
[tf-s3]: https://developer.hashicorp.com/terraform/language/backend/s3#enabling-s3-state-locking
[tf-state]: https://www.terraform.io/docs/language/state/index.html
[update-k8s]: https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html
[vpc-requirements]: https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
[vpc-subnets]: https://docs.aws.amazon.com/eks/latest/userguide/creating-a-vpc.html
