variable "aws_region" {
  description = "AWS region for the workload."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "prod"
}

variable "owner" {
  description = "Owning team/client."
  type        = string
  default     = "NimbusTech"
}

variable "cost_center" {
  description = "Cost allocation tag."
  type        = string
  default     = "NIMBUS-APP"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "app_port" {
  description = "Node.js application port behind the ALB."
  type        = number
  default     = 3000
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_name" {
  type    = string
  default = "nimbus"
}

variable "db_username" {
  type    = string
  default = "nimbusadmin"
}

variable "db_password" {
  description = "Temporary lab password. Use Secrets Manager in production."
  type        = string
  sensitive   = true
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version. Confirm regional availability before apply."
  type        = string
  default     = "18"
}

variable "certificate_arn" {
  description = "Optional ACM certificate ARN for HTTPS. Leave empty to create HTTP only."
  type        = string
  default     = ""
}

variable "ami_id" {
  description = "Optional AMI ID for the application tier. If empty, use latest AL2023 SSM parameter."
  type        = string
  default     = ""
}
