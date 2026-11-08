locals {
  region = "us-east-2"

  cluster_name = "example"

  tags = {
    Region      = local.region
    Environment = "production"
    Managed-by  = "Terraform"
    Owner       = "ops"
  }
}
