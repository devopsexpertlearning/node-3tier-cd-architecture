variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }

variable "security_groups" {
  description = "Map of security groups to create. Each entry defines a security group with ingress and egress rules."
  type        = any
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
