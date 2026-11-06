variable "enabled" {
  description = "Toggle resource creation. Module skips creating any resources when set to `false`."
  type        = bool
  default     = true
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
  description = "Host root block device volume size in GiB. It cannot be smaller thant the AMI being used."
  type        = number
  default     = 8
}

variable "disable_api_termination" {
  description = "Toggle EC2 instance termination protection."
  type        = bool
  default     = false
}

variable "metadata_http_endpoint_enabled" {
  description = "Enable the metadata instance service."
  type        = bool
  default     = false
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
  type        = set(string)
}

variable "security_groups" {
  description = "VPC Security group IDs."
  type        = set(string)
}

variable "tags" {
  description = "Map of tags to add to every resource managed by this module."
  type        = map(string)
  default     = {}
}

# variable "user_data_base64" {
#   description = ""
#   type        =
#   default     =
# }
