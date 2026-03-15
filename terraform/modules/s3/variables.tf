variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket to create (must be globally unique)"
  type        = string
}

variable "enable_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "A boolean that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error"
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "List of maps containing lifecycle rule configuration"
  type = list(object({
    id = string
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    expiration = optional(list(object({
      days = number
    })), [])
  }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
