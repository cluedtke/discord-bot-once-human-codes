provider "aws" {
  profile = var.aws_profile
  region  = "us-east-1"
}

locals {
  app_name = "once-human-codes"
}

variable "aws_profile" {
  description = "AWS profile to use"
  default     = "default"
}

variable "discord_webhook" {
  description = "Discord webhook token"
  default     = "default_value"
  sensitive   = true
}
