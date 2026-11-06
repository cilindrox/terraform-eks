locals {
}

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "this" {
  count = var.enabled ? 1 : 0

  ami                  = coalesce(var.ami_id, data.aws_ssm_parameter.ami.value)
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.this[0].name

  # FIXME
  # user_data              = length(var.user_data_base64) > 0 ? var.user_data_base64 : local.user_data_templated
  # vpc_security_group_ids = compact(concat(module.security_group[*].id, var.security_groups))

  associate_public_ip_address = false
  key_name                    = ""
  subnet_id                   = var.subnets[0]
  monitoring                  = var.monitoring
  disable_api_termination     = var.disable_api_termination

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
}
