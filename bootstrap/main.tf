locals {
  name        = "tf-state"
  bucket_name = "${local.name}.example.com"
  region      = "us-east-2"

  tags = {
    Region      = local.region
    Environment = "bootstrap"
    Managed-by  = "Terraform"
    Owner       = "ops"
  }
}

module "s3_bucket" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=9afa4fc8c8f1e0b3fd913474c1bef8d0c454b235" # 5.17.0

  bucket = local.bucket_name

  attach_deny_insecure_transport_policy = true
  control_object_ownership              = true
  object_ownership                      = "BucketOwnerEnforced"

  force_destroy = false

  lifecycle_rule = [{
    id                                     = "expire-old-versions"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 3
    expiration = {
      expired_object_delete_marker = true
    }
    noncurrent_version_expiration = {
      noncurrent_days           = 30
      newer_noncurrent_versions = 2
    }
  }]

  versioning = {
    enabled = true
  }
}
