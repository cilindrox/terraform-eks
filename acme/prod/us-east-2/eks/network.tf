##
# EKS VPCs
##

data "aws_availability_zones" "available" {
  state                  = "available"
  all_availability_zones = false

  filter {
    name = "zone-name"
    values = [
      "${local-region}a",
      "${local-region}b",
      "${local-region}c",
    ]
  }
}

locals {
  vpc_cidr = "10.20.0.0/16"

  subnet_newbits      = 3
  vpc_private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, local.subnet_newbits, k + length(local.azs) + 1)]
  vpc_public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, local.subnet_newbits, k + 1)]
  azs                 = data.aws_availability_zones.available.names

  # ref: https://docs.aws.amazon.com/vpc/latest/privatelink/aws-services-privatelink-support.html
  #
  interface_endpoint_services = toset([
    "application-autoscaling",
    "ec2",
    "ec2messages",
    "ecr.api",
    "ecr.dkr",
    "eks",
    "eks-auth",
    "elasticloadbalancing",
    "kms",
    "logs",
    "rds",
    "secretsmanager",
    "sqs",
    "ssm",
    "ssmmessages",
    "sts",
  ])

  # ref: https://aws.amazon.com/blogs/architecture/choosing-your-vpc-endpoint-strategy-for-amazon-s3/
  gateway_endpoint_services = toset([
    "s3",
  ])

  nat_gw_name = "nat-gw"
}

module "vpc" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git?ref=b3abd6df2ecf052451a361ed55b8f06f8742a795" # 6.7.3

  name = local.cluster_name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = local.vpc_public_subnets
  private_subnets = local.vpc_private_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  reuse_nat_ips          = true
  external_nat_ip_ids    = [for i in aws_eip.nat : i.id]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.cluster_name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.cluster_name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.cluster_name}-default" }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = local.cluster_name
  }

  tags = local.tags
}

module "flow_log" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git//modules/flow-log?ref=b3abd6df2ecf052451a361ed55b8f06f8742a795" # 6.7.3

  name   = module.vpc.vpc_id
  vpc_id = module.vpc.vpc_id

  cloudwatch_log_group_retention_in_days = 30

  tags = local.tags
}

##
# VPC Endpoints
##

module "endpoints" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc.git//modules/vpc-endpoints?ref=b3abd6df2ecf052451a361ed55b8f06f8742a795" # 6.7.3

  vpc_id = module.vpc.vpc_id

  create_security_group      = true
  security_group_description = "VPC Endpoint security group for eks:${local.cluster_name}."
  security_group_name_prefix = "vpc-se-${local.cluster_name}"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  # ref: https://docs.aws.amazon.com/eks/latest/userguide/private-clusters.html
  endpoints = merge({ for g in local.gateway_endpoint_services : g => {
    service      = g
    service_type = "Gateway"
    route_table_ids = flatten([
      module.vpc.intra_route_table_ids,
      module.vpc.private_route_table_ids,
      module.vpc.public_route_table_ids,
    ])

    tags = { Name = "${local.cluster_name}-vpc-${g}-ep" }
    } },
    { for s in local.interface_endpoint_services : replace(s, ".", "-") => {
      service             = s
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets

      tags = { Name = "${local.cluster_name}-vpc-${replace(s, ".", "-")}-ep" }
  } })

  tags = merge(local.tags, {
    Cluster = local.cluster_name
  })
}

##
# NAT Gateway
##

# Reserve one Elastic IP per NAT GW az.
#
#checkov:skip=CKV_AWS_19:EIP addresses are assigned to module.vpc.external_nat_ip_ids.
# IPs are attached to the default aws_nat_gateway resource.
# https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/b3abd6df2ecf052451a361ed55b8f06f8742a795/main.tf#L1204

resource "aws_eip" "nat" {
  for_each = toset(module.vpc.azs)

  domain = "vpc"

  tags = merge(local.tags, {
    Name    = "${local.nat_gw_name}-${each.value}"
    Cluster = local.cluster_name
    Az      = each.value
    Vpc     = module.vpc.vpc_id
  })
}

##
# Bastion Host
##

module "bastion-host" {
  source                          = "../../../../modules/bastion-host"

  tag_application                 = var.tag_application
  target_environment              = var.target_environment

  subnet_id                       = module.vpc.private_subnets[0]

  bastion_host_security_group_ids = [module.bastion-vpc.vpc_bastion_host_security_group]

  bastion_host_policy             = var.bastion_host_policy
}
