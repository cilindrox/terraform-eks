locals {
  kubernetes_version = "1.37"
}

module "eks" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=91f11ea01656c26b8e6b8eb1b74f19863f60056c" # v21.29.0
  name   = local.cluster_name

  kubernetes_version = local.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # TODO(gfestari): restrict access to VPN
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"]

  access_entries = {
    admin = {
      # TODO(gfestari): roles need to exist in the account or managed here under
      # iam.tf
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.id}:role/clusterAdmin"

      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    viewer = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.id}:role/clusterViewer"

      policy_associations = {
        example = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            namespaces = ["default"]
            type       = "namespace"
          }
        }
      }
    }
  }

  deletion_protection = true

  kms_key_administrators = [
    # TODO(gfestari): roles need to exist in the account. This falls back to the
    # id of the user performing the apply.
    "arn:aws:iam::${data.aws_caller_identity.current.id}:role/clusterAdmin",
  ]

  # Depending on the controller, additional rules might be required:
  # https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2359
  #
  # node_security_group_additional_rules = {
  #   ingress_self_tcp = {
  #     description = "Node to node 80-1024/tcp"
  #     protocol    = "tcp"
  #     from_port   = 80
  #     to_port     = 1024
  #     type        = "ingress"
  #     self        = true
  #   }
  # }

  enabled_log_types = [
    "audit",
    "authenticator",
    "api",
    "controllerManager",
    "scheduler",
  ]

  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  addons = {
    aws-ebs-csi-driver = {
      addon_version = "v1.67.2-eksbuild.1"
      configuration_values = jsonencode({
        controller = {
          volumeModificationFeature = {
            enabled = true
          }
          enableMetrics               = true
          enablePrometheusAnnotations = false
        }
        node = {
          enableWindows               = false
          enableMetrics               = true
          enablePrometheusAnnotations = false
        }
      })
    }
    coredns = {
      addon_version = "v1.14.7-eksbuild.35"
      configuration_values = jsonencode({
        autoScaling = {
          enabled     = true
          minReplicas = 3
          maxReplicas = 9
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            memory = "256Mi"
          }
        }
      })
    }
    eks-node-monitoring-agent = {
      addon_version = "v1.7.6-eksbuild.1"
    }
    eks-pod-identity-agent = {
      addon_version  = "v1.4.1-eksbuild.3"
      before_compute = true
    }
    kube-proxy = {
      addon_version = "v1.37.0-eksbuild.34"
    }
    snapshot-controller = {
      addon_version = "v8.7.0-eksbuild.2"
      # Pin controller to the dedicated cluster-autoscaler managed node group.
      configuration_values = jsonencode({
        affinity = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [{
                matchExpressions = [{
                  key      = "type"
                  operator = "In"
                  values   = ["addons"]
                }]
              }]
            }
          }
          podAntiAffinity = null
        }
        nodeSelector = null
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
          },
          {
            effect            = "NoExecute"
            operator          = "Exists"
            tolerationSeconds = 300
          },
        ]
        topologySpreadConstraints = [{
          labelSelector = {
            matchLabels = {
              app = "snapshot-controller"
            }
          }
          matchLabelKeys    = ["pod-template-hash"]
          maxSkew           = 1
          topologyKey       = "topology.kubernetes.io/zone"
          whenUnsatisfiable = "ScheduleAnyway"
        }]
      })
    }
    vpc-cni = {
      addon_version  = "v1.23.2-eksbuild.10"
      before_compute = true
      preserve       = true
    }
  }

  eks_managed_node_groups = {
    cluster_addons = {
      instance_types = ["t4g.small"]
      ami_type       = "AL2023_ARM_64_STANDARD"
      desired_size   = 3
      min_size       = 1
      max_size       = 6

      update_config = {
        max_unavailable_percentage = 33
      }

      node_repair_config = {
        enabled = true
      }

      taints = {
        addons_only = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      labels = {
        environment = "production"
        type        = "addons"
      }

      tags = {
        nodegroup-role = "addons"
        nodegroup-type = "managed"
      }
    }
  }
}
