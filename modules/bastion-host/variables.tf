variable "enabled" {
  description = "Toggle resource creation. Module skips creating any resources when set to `false`."
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Name prefix applied to every resource managed by this module."
  type        = string
  default     = "eks-ssm-bastion-"
}

variable "ami_id" {
  description = "Override the default EC2 host AMI id."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t4g.small"
}

variable "root_block_device_encrypted" {
  description = "Toggle encryption for the host's root block device."
  type        = bool
  default     = true
}

variable "root_block_device_volume_size" {
  description = "Host root block device volume size in GiB. It cannot be smaller than the AMI being used."
  type        = number
  default     = 8
}

variable "disable_api_termination" {
  description = "Enable [EC2 Instance Termination Protection](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Using_ChangingDisableAPITermination.html)."
  type        = bool
  default     = false
}

variable "disable_api_stop" {
  description = "Enable [EC2 Instance Stop Protection](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-stop-protection.html)."
  type        = bool
  default     = false
}

variable "metadata_http_endpoint_enabled" {
  description = "Enable the metadata instance service."
  type        = bool
  default     = true
}

variable "metadata_http_put_response_hop_limit" {
  description = "HTTP PUT response hop limit for instance metadata requests."
  type        = number
  default     = 1

  validation {
    condition     = var.metadata_http_put_response_hop_limit > 0 && var.metadata_http_put_response_hop_limit < 65
    error_message = "HTTP PUT response hop limit must be between 1 and 64."
  }
}

variable "metadata_http_tokens_required" {
  description = "Use session tokens to reach the Instance Metadata Service v2."
  type        = bool
  default     = true
}

variable "monitoring" {
  description = "Enable EC2 instance detailed monitoring."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "subnets" {
  description = "List of AWS Subnet IDs for the EC2 instance."
  type        = list(string)
}

variable "security_groups" {
  description = "A list of Security group IDs to associate with the EC2 instance."
  type        = list(string)
  default     = []
}

variable "security_group_rules" {
  description = "Egress security group rules."
  type = list(object({
    description = optional(string)
    from_port   = optional(number)
    to_port     = optional(number)
    protocol    = optional(string)
    cidr_blocks = optional(list(string))
  }))
  default = [
    {
      description = "Allow outbound HTTPS traffic to AWS SSM endpoints"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Allow outbound DNS to Amazon Provided DNS"
      from_port   = 53
      to_port     = 53
      protocol    = "udp"
      cidr_blocks = ["169.254.169.253/32"]
    },
    {
      description = "Allow outbound DNS upgrades to Amazon Provided DNS"
      from_port   = 53
      to_port     = 53
      protocol    = "tcp"
      cidr_blocks = ["169.254.169.253/32"]
    },
  ]
}

variable "tags" {
  description = "Map of tags to add to every resource managed by this module."
  type        = map(string)
  default     = {}
}

variable "user_data_base64" {
  description = "Base64-encoded user data string for the EC2 bastion host instance."
  type        = string
  default     = ""

  validation {
    condition     = var.user_data_base64 == "" || can(base64decode(var.user_data_base64))
    error_message = "User data must be a valid base64-encoded string."
  }
}

variable "ebs_block_device_encrypted" {
  description = "Toggle the additional EBS block device encryption."
  type        = bool
  default     = true
}

variable "ebs_block_device_volume_size" {
  description = "Volume size in GiB for the creation of an additional EBS block device. Ignored if size is 0."
  type        = number
  default     = 0
}

variable "ebs_delete_on_termination" {
  description = "Toggle destruction of the the EBS volume on instance termination."
  type        = bool
  default     = true
}

variable "ebs_device_name" {
  description = "Name of the EBS block device to mount on the instance."
  type        = string
  default     = "/dev/sdh"
}

variable "ebs_snapshot_id" {
  description = "Use a snapshot id for the additional EBS block device. Ignored when specifying `ebs_block_device_volume_size` > 0."
  type        = string
  default     = ""
}
