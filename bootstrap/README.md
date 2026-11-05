# Bootstrap

This module creates the resources required for an [S3 backend] on Terraform.

This module is meant to be _run once_ by an operator with admin access, either
when initially setting up a main account or during disaster recovery procedures.

## Usage

This is intended as a bootstrap script for the different Terraform
environments under the `acme` folder.

For initial usage, an operator with the appropriate access credentials will
need to:

1. Install the modules, and `plan` the environment changes:

```bash
make bootstrap
```

2. Verify the output and apply the changes:

```bash
terraform -chdir=./bootstrap apply tfplan
```

> **WARNING**: this bucket will contain all the environment's remote state files.
> Manage its resources carefully.

[S3 backend]: https://developer.hashicorp.com/terraform/language/settings/backends/s3

<!-- markdownlint-disable MD034 -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.17 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.72.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git | 9afa4fc8c8f1e0b3fd913474c1bef8d0c454b235 |

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->
