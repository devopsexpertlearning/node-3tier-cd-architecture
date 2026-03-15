# EKS Module

locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = var.security_group_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
  }

  enabled_cluster_log_types = var.enabled_log_types

  tags = merge(local.common_tags, {
    Name = local.cluster_name
  })
}

# OIDC Provider for IRSA (IAM Roles for Service Accounts)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = local.common_tags
}


