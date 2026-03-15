# Fargate Profile Module

# Fargate Profile Module

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# Fargate Profiles for application workloads
resource "aws_eks_fargate_profile" "this" {
  for_each = var.profiles

  cluster_name = var.cluster_name
  # Use explicit name if provided, otherwise generate one using the map key
  fargate_profile_name   = coalesce(each.value.name, "${var.project_name}-${var.environment}-${each.key}")
  pod_execution_role_arn = var.fargate_pod_execution_role_arn
  subnet_ids             = var.subnet_ids

  dynamic "selector" {
    for_each = each.value.selectors
    content {
      namespace = selector.value.namespace
      labels    = length(selector.value.labels) > 0 ? selector.value.labels : null
    }
  }

  tags = merge(local.common_tags, {
    Name = coalesce(each.value.name, "${var.project_name}-${var.environment}-${each.key}")
  })
}

# EKS Add-ons (Moved here to ensure compute is available before installing)
resource "aws_eks_addon" "main" {
  for_each = var.addons

  cluster_name                = var.cluster_name
  addon_name                  = each.key
  addon_version               = try(each.value.version, null)
  resolve_conflicts_on_create = try(each.value.resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(each.value.resolve_conflicts_on_update, "OVERWRITE")
  service_account_role_arn    = try(each.value.service_account_role_arn, null)
  configuration_values        = try(each.value.configuration_values, null)

  tags = local.common_tags

  # Ensure Add-ons wait for all compute (Fargate Profiles) to be created
  depends_on = [aws_eks_fargate_profile.this]
}
