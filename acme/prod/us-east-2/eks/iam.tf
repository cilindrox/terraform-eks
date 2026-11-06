locals {
  # TODO(gfestari): see comment below regarding Route53 zones.
  # r53_zones = toset([
  #   "example.com.",
  # ])

  pod_identity_applications = {
    # cert-manager = {
    #   attach_cert_manager_policy    = true
    #   namespace                     = "cert-manager"
    #   service_account               = "cert-manager"
    #   cert_manager_hosted_zone_arns = [for z in data.aws_route53_zone.selected : z.arn]
    # }
    cluster-autoscaler = {
      attach_cluster_autoscaler_policy = true
      namespace                        = "kube-system"
      service_account                  = "cluster-autoscaler-sa"
      cluster_autoscaler_cluster_names = [local.cluster_name]
    }
    # external-dns = {
    #   attach_external_dns_policy    = true
    #   namespace                     = "kube-system"
    #   service_account               = "external-dns-r53"
    #   external_dns_hosted_zone_arns = [for z in data.aws_route53_zone.selected : z.arn]
    # }
    external-secrets = {
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
    aws-ebs-csi = {
      attach_aws_ebs_csi_policy = true
      namespace                 = "kube-system"
      service_account           = "ebs-csi-controller-sa"
      # aws_ebs_csi_kms_arns      = ["arn:aws:kms:*:*:key/1234abcd-12ab-34cd-56ef-1234567890ab"]
    }
    aws-lbc = {
      attach_aws_lb_controller_policy = true
      namespace                       = "kube-system"
      service_account                 = "aws-load-balancer-controller"
    }
    vpc-cni = {
      attach_aws_vpc_cni_policy          = true
      namespace                          = "kube-system"
      service_account                    = "aws-node"
      aws_vpc_cni_enable_cloudwatch_logs = true
      aws_vpc_cni_enable_ipv4            = true
    }
  }
}

data "aws_caller_identity" "current" {}

# TODO(gfestari): block commented to prevent a
# "no matching Route 53 Hosted Zone found" error during plan.
#
# Uncomment this along with external-dns and cert-manager above when using an
# existing zone on the account.
#
# data "aws_route53_zone" "selected" {
#   for_each = local.r53_zones

#   name = each.key
# }

# Create a Pod Identity Roles for each of the in-cluster applications that
# require access to AWS services.
#
# ref: https://docs.aws.amazon.com/eks/latest/userguide/pod-id-how-it-works.html
#
module "pod_identity" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks-pod-identity.git?ref=f72040b99272c264e0340f44758219e0808a52a2" # v2.10.0

  for_each = local.pod_identity_applications

  name            = try(each.value.name, each.key)
  path            = try(each.value.path, null)
  use_name_prefix = try(each.value.use_name_prefix, false)

  attach_custom_policy   = try(each.value.attach_custom_policy, false)
  policy_statements      = try(each.value.policy_statements, null)
  additional_policy_arns = try(each.value.additional_policy_arns, {})

  attach_cert_manager_policy    = try(each.value.attach_cert_manager_policy, false)
  cert_manager_hosted_zone_arns = try(each.value.cert_manager_hosted_zone_arns, [])

  attach_cluster_autoscaler_policy = try(each.value.attach_cluster_autoscaler_policy, false)
  cluster_autoscaler_cluster_names = try(each.value.cluster_autoscaler_cluster_names, [])

  attach_external_dns_policy    = try(each.value.attach_external_dns_policy, false)
  external_dns_hosted_zone_arns = try(each.value.external_dns_hosted_zone_arns, [])

  attach_aws_ebs_csi_policy = try(each.value.attach_aws_ebs_csi_policy, false)
  aws_ebs_csi_kms_arns      = try(each.value.aws_ebs_csi_kms_arns, [])

  attach_aws_lb_controller_policy = try(each.value.attach_aws_lb_controller_policy, false)

  attach_velero_policy       = try(each.value.attach_velero_policy, false)
  velero_s3_bucket_arns      = try(each.value.velero_s3_bucket_arns, [])
  velero_s3_bucket_path_arns = try(each.value.velero_s3_bucket_path_arns, [])

  attach_aws_vpc_cni_policy          = try(each.value.attach_aws_vpc_cni_policy, false)
  aws_vpc_cni_enable_cloudwatch_logs = try(each.value.aws_vpc_cni_enable_cloudwatch_logs, false)
  aws_vpc_cni_enable_ipv4            = try(each.value.aws_vpc_cni_enable_ipv4, false)
  aws_vpc_cni_enable_ipv6            = try(each.value.aws_vpc_cni_enable_ipv6, false)

  trust_policy_conditions = [
    {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.id]
    },
    {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-namespace"
      values   = [each.value.namespace]
    },
    {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-service-account"
      values   = [each.value.service_account]
    },
    {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks-cluster-name"
      values   = [local.cluster_name]
    },
  ]

  associations = {
    this = {
      cluster_name    = try(each.value.cluster_name, local.cluster_name) # using the var instead of module.eks.cluster_id avoids a circular dep.
      namespace       = each.value.namespace
      service_account = each.value.service_account
    }
  }

  tags = local.tags
}
