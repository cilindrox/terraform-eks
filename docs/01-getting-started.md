# Getting Started

You will need a set of IAM account credentials with the appropriate permissions.

Provision the default Terraform state bucket on the account via:

```bash
make bootstrap
```

This will `init` and `plan` the [S3 bucket] creation under the `bootstrap`
directory. This bucket is used for storing each individual environment's
[Terraform state][tf-state].

Apply the changes via:

```bash
terraform -chdir=bootstrap apply
```

These steps are required for initial bucket creation and in case of disaster
recovery.

## Accessing the Kubernetes Cluster

The EKS cluster's control plane API endpoint is only accessible using AWS
Systems Manager (SSM) Session Manager. Make sure both the [Session Manager
plugin for the AWS CLI][session-manager-plugin] and [kubectl] are installed
before proceeding.

This implementation uses a private EC2 bastion host inside the cluster VPC's
private subnet.

You'll need to initiate a port forwarding session using the AWS CLI and SSM:

```bash
# Fetch the bastion instance ID from terraform's output
AWS_REGION='us-east-2'
CLUSTER_DIR="acme/prod/${AWS_REGION}/eks"
BASTION_INSTANCE_ID=$(terraform -chdir="${CLUSTER_DIR}" output -raw bastion_instance_id)
CLUSTER_ENDPOINT=$(terraform -chdir="${CLUSTER_DIR}" output -raw cluster_endpoint)

# SSM needs a bare URL, strip the https:// scheme.
CLUSTER_HOST="${CLUSTER_ENDPOINT#https://}"

# Start the port-forwarding session
aws ssm start-session \
  --region "${AWS_REGION}" \
  --target "${BASTION_INSTANCE_ID}" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${CLUSTER_HOST}\"],\"portNumber\":[\"443\"],\"localPortNumber\":[\"8443\"]}"
```

> **NOTE**: this session must stay open in the background or another terminal session.

Once port-forwarding is configured, you will need to update your `$KUBECONFIG`
file to instruct `kubectl` to use the tunnel. During initial setup, this is done
via the following aws-cli command:

```bash
CLUSTER_NAME=$(terraform -chdir="${CLUSTER_DIR}" output -raw cluster_name)

aws eks update-kubeconfig \
  --region "${AWS_REGION}" \
  --name "${CLUSTER_NAME}" \
  --alias private-eks-cluster \
  --proxy-url http://localhost:8443
```

This will add the `proxy-url` parameter to the `cluster` block, eg:

```yaml
# ~/.kube/config
clusters:
- cluster:
    certificate-authority-data: <BASE64_DATA>
    server: <CLUSTER_HOST>
    proxy-url: http://localhost:8443
  name: private-eks-cluster
```

> **NOTE**: the `proxy-url` config above uses a local HTTP CONNECT proxy.
> Even if the scheme is `http`, kubectl will tunnel TLS over the local proxy to
> talk to the API server.

The bastion host is provisioned via a [custom terraform
module](../modules/bastion-host).

### Using a VPN

An alternative to the bastion deployment would be restricting the endpoint's
public access to an IP or CIDR controlled by the managing teams, such as a VPN,
eg:

```diff
module "eks" {
+  endpoint_public_access       = true
+  endpoint_public_access_cidrs = ["10.5.4.3/32"] # VPN IP
}
```

## Troubleshooting

If you see "An error occurred (`AccessDeniedException`)", check that the IAM
permissions for the caller include `ssm:StartSession`.

If you get `Forbidden` errors after connecting with a working tunnel, check
that RBAC has been granted for your principal or an EKS access entry exists for
your role. Access entries are declared using the `module.eks.access_entries`
variable.

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

[S3 bucket]: https://developer.hashicorp.com/terraform/language/backend/s3#enabling-s3-state-locking
[kubectl]: https://kubernetes.io/docs/tasks/tools/#kubectl
[session-manager-plugin]: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
[tf-state]: https://www.terraform.io/docs/language/state/index.html
[vpc-requirements]: https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
[vpc-subnets]: https://docs.aws.amazon.com/eks/latest/userguide/creating-a-vpc.html
