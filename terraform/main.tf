provider "aws" {
  profile = "free"
  region  = "us-east-1"
}

locals {
  app_name = "once-human-codes"
}

variable "discord_webhook" {
  description = "Discord webhook token"
  default     = "default_value"
  sensitive   = true
}
