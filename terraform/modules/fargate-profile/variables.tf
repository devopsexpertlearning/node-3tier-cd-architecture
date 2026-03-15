variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "fargate_pod_execution_role_arn" {
  description = "ARN of the Fargate pod execution IAM role"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for Fargate tasks"
  type        = list(string)
}

variable "profiles" {
  description = <<EOF
Map of Fargate profiles to create. Key is a logical identifier, value is an object with:
  - name: (optional) The explicit name of the Fargate profile. If omitted, a name is generated.
  - selectors: (required) A list of maps containing 'namespace' and optionally 'labels'.
EOF
  type = map(object({
    name = optional(string)
    selectors = list(object({
      namespace = string
      labels    = optional(map(string), {})
    }))
  }))
  default = {
    app = {
      selectors = [
        { namespace = "default" },
        { namespace = "kube-system" }
      ]
    }
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "addons" {
  description = "EKS Add-ons to enable for the cluster after Fargate profiles are created"
  type        = any
  default     = {}
}
