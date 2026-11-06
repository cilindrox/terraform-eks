# Bastion Host

This Terraform module creates a generic Bastion host with support for AWS SSM
Session Manager for remote access with IAM authentication.

## Usage

```hcl
# module.vpc defines a VPC which will be shared with the bastion host.
module "vpc" {
  # ...
}

module "bastion" {
  source = "./modules/bastion-host"

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
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
```

<!-- markdownlint-disable MD034 MD052 -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.59 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.59 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_ssm_parameter.ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | List of AWS Subnet IDs for the EC2 instance. | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID. | `string` | n/a | yes |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | Override the default EC2 host AMI id. | `string` | `""` | no |
| <a name="input_disable_api_stop"></a> [disable\_api\_stop](#input\_disable\_api\_stop) | Enable [EC2 Instance Stop Protection](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-stop-protection.html). | `bool` | `false` | no |
| <a name="input_disable_api_termination"></a> [disable\_api\_termination](#input\_disable\_api\_termination) | Enable [EC2 Instance Termination Protection](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Using_ChangingDisableAPITermination.html). | `bool` | `false` | no |
| <a name="input_ebs_block_device_encrypted"></a> [ebs\_block\_device\_encrypted](#input\_ebs\_block\_device\_encrypted) | Toggle the additional EBS block device encryption. | `bool` | `true` | no |
| <a name="input_ebs_block_device_volume_size"></a> [ebs\_block\_device\_volume\_size](#input\_ebs\_block\_device\_volume\_size) | Volume size in GiB for the creation of an additional EBS block device. Ignored if size is 0. | `number` | `0` | no |
| <a name="input_ebs_delete_on_termination"></a> [ebs\_delete\_on\_termination](#input\_ebs\_delete\_on\_termination) | Toggle destruction of the the EBS volume on instance termination. | `bool` | `true` | no |
| <a name="input_ebs_device_name"></a> [ebs\_device\_name](#input\_ebs\_device\_name) | Name of the EBS block device to mount on the instance. | `string` | `"/dev/sdh"` | no |
| <a name="input_ebs_snapshot_id"></a> [ebs\_snapshot\_id](#input\_ebs\_snapshot\_id) | Use a snapshot id for the additional EBS block device. Ignored when specifying `ebs_block_device_volume_size` > 0. | `string` | `""` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Toggle resource creation. Module skips creating any resources when set to `false`. | `bool` | `true` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type. | `string` | `"t4g.small"` | no |
| <a name="input_metadata_http_endpoint_enabled"></a> [metadata\_http\_endpoint\_enabled](#input\_metadata\_http\_endpoint\_enabled) | Enable the metadata instance service. | `bool` | `true` | no |
| <a name="input_metadata_http_put_response_hop_limit"></a> [metadata\_http\_put\_response\_hop\_limit](#input\_metadata\_http\_put\_response\_hop\_limit) | HTTP PUT response hop limit for instance metadata requests. | `number` | `1` | no |
| <a name="input_metadata_http_tokens_required"></a> [metadata\_http\_tokens\_required](#input\_metadata\_http\_tokens\_required) | Use session tokens to reach the Instance Metadata Service v2. | `bool` | `true` | no |
| <a name="input_monitoring"></a> [monitoring](#input\_monitoring) | Enable EC2 instance detailed monitoring. | `bool` | `true` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Name prefix applied to every resource managed by this module. | `string` | `"eks-ssm-bastion-"` | no |
| <a name="input_root_block_device_encrypted"></a> [root\_block\_device\_encrypted](#input\_root\_block\_device\_encrypted) | Toggle encryption for the host's root block device. | `bool` | `true` | no |
| <a name="input_root_block_device_volume_size"></a> [root\_block\_device\_volume\_size](#input\_root\_block\_device\_volume\_size) | Host root block device volume size in GiB. It cannot be smaller than the AMI being used. | `number` | `8` | no |
| <a name="input_security_group_rules"></a> [security\_group\_rules](#input\_security\_group\_rules) | Egress security group rules. | <pre>list(object({<br/>    description = optional(string)<br/>    from_port   = optional(number)<br/>    to_port     = optional(number)<br/>    protocol    = optional(string)<br/>    cidr_blocks = optional(list(string))<br/>  }))</pre> | <pre>[<br/>  {<br/>    "cidr_blocks": [<br/>      "0.0.0.0/0"<br/>    ],<br/>    "description": "Allow outbound HTTPS traffic to AWS SSM endpoints",<br/>    "from_port": 443,<br/>    "protocol": "tcp",<br/>    "to_port": 443<br/>  },<br/>  {<br/>    "cidr_blocks": [<br/>      "169.254.169.253/32"<br/>    ],<br/>    "description": "Allow outbound DNS to Amazon Provided DNS",<br/>    "from_port": 53,<br/>    "protocol": "udp",<br/>    "to_port": 53<br/>  },<br/>  {<br/>    "cidr_blocks": [<br/>      "169.254.169.253/32"<br/>    ],<br/>    "description": "Allow outbound DNS upgrades to Amazon Provided DNS",<br/>    "from_port": 53,<br/>    "protocol": "tcp",<br/>    "to_port": 53<br/>  }<br/>]</pre> | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | A list of Security group IDs to associate with the EC2 instance. | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to add to every resource managed by this module. | `map(string)` | `{}` | no |
| <a name="input_user_data_base64"></a> [user\_data\_base64](#input\_user\_data\_base64) | Base64-encoded user data string for the EC2 bastion host instance. | `string` | `""` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the bastion host EC2 instance. |
| <a name="output_id"></a> [id](#output\_id) | Bastion host EC2 Instance ID. |
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | Private IP of the bastion host EC2 instance. |
| <a name="output_role"></a> [role](#output\_role) | ARN of AWS IAM Role associated with the instance. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the bastion host's security group. |
<!-- END_TF_DOCS -->
