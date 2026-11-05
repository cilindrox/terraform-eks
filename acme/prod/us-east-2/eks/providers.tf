terraform {
  required_version = "~> 1.17"

  backend "s3" {
    bucket       = "tf-state.example.com"
    region       = "us-east-2"
    key          = "prod/us-east-2/eks.tfstate"
    use_lockfile = true
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.72.0"
    }
  }
}

provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}
