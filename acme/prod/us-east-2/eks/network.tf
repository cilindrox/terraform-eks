##
# EKS VPCs
##

data "aws_availability_zones" "available" {
  state                  = "available"
  all_availability_zones = false

  filter {
    name = "zone-name"
    values = [
      "${local.region}a",
      "${local.region}b",
      "${local.region}c",
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
    "ec2",
    "ec2messages",
    "ecr.api",
    "ecr.dkr",
    "eks",
    "eks-auth",
    "elasticloadbalancing",
    "kms",
    "logs",
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
  external_nat_ip_ids    = [for az in local.azs : aws_eip.nat[az].id]

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
# IPs are attached to the default aws_nat_gateway resource.
resource "aws_eip" "nat" {
  #checkov:skip=CKV2_AWS_19:EIP addresses are assigned to module.vpc.external_nat_ip_ids.
  for_each = toset(local.azs)

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

module "bastion" {
  source = "../../../../modules/bastion-host"

  # Instance is accessible only via SSM
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.private_subnets

  # The instance must be able to reach public AWS SSM endpoints or VPC endpoints
  # on port 443
  security_group_rules = [
    {
      description = "Allow outbound HTTPS traffic to AWS SSM endpoints"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    },
    {
      description = "Allow outbound DNS to Amazon Provided DNS"
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = ["169.254.169.253/32"]
    },
    {
      description = "Allow outbound DNS upgrades to Amazon Provided DNS"
      from_port   = 53
      to_port     = 53
      protocol    = "tcp"
      cidr_blocks = ["169.254.169.253/32"]
    },
  ]

  tags = merge(local.tags, {
    Name    = "${local.cluster_name}-bastion"
    Cluster = local.cluster_name
    Vpc     = module.vpc.vpc_id
  })
}
