locals {
  region = "us-east-2"

  cluster_name = "example"

  tags = {
    Region      = local.region
    Environment = "eks"
    Managed-by  = "Terraform"
    Owner       = "ops"
  }
}
