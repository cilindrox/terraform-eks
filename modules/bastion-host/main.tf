data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_instance" "this" {
  count = var.enabled ? 1 : 0

  ami                  = coalesce(var.ami_id, data.aws_ssm_parameter.ami.value)
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.this[0].name
  user_data_base64     = var.user_data_base64

  vpc_security_group_ids = compact(concat(
    [aws_security_group.this[0].id], var.security_groups
  ))

  associate_public_ip_address = false
  key_name                    = ""
  subnet_id                   = var.subnets[0]
  monitoring                  = var.monitoring
  disable_api_termination     = var.disable_api_termination
  disable_api_stop            = var.disable_api_stop

  metadata_options {
    http_endpoint               = (var.metadata_http_endpoint_enabled) ? "enabled" : "disabled"
    http_put_response_hop_limit = var.metadata_http_put_response_hop_limit
    http_tokens                 = (var.metadata_http_tokens_required) ? "required" : "optional"
  }

  root_block_device {
    encrypted   = var.root_block_device_encrypted
    volume_size = var.root_block_device_volume_size
  }

  ebs_optimized = true

  dynamic "ebs_block_device" {
    for_each = var.ebs_block_device_volume_size > 0 ? [1] : []

    content {
      encrypted             = var.ebs_block_device_encrypted
      volume_size           = var.ebs_block_device_volume_size
      delete_on_termination = var.ebs_delete_on_termination
      device_name           = var.ebs_device_name
      snapshot_id           = var.ebs_snapshot_id
    }
  }

  tags = var.tags

  # Defer launching the instance until after the policy is attached.
  depends_on = [
    aws_iam_role_policy_attachment.ssm,
  ]
}

resource "aws_security_group" "this" {
  #checkov:skip=CKV2_AWS_5:Security Group is exported via module outputs and attached to resources externally.
  count = var.enabled ? 1 : 0

  name_prefix = var.name_prefix
  description = "Security group for SSM session manager bastion host."
  vpc_id      = var.vpc_id

  dynamic "egress" {
    for_each = var.security_group_rules
    iterator = rule

    content {
      description = rule.value.description
      from_port   = try(rule.value.from_port, null)
      to_port     = try(rule.value.to_port, null)
      protocol    = try(rule.value.protocol, null)
      cidr_blocks = try(rule.value.cidr_blocks, null)
    }
  }

  tags = var.tags
}
