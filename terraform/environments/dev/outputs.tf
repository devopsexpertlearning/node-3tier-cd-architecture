# NETWORKING

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# EKS

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority" {
  description = "EKS cluster certificate authority data (base64) — required for kubeconfig and CI/CD"
  value       = module.eks.cluster_certificate_authority
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN (for IRSA)"
  value       = module.eks.oidc_provider_arn
}

# IAM

output "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller — annotate on its Kubernetes ServiceAccount"
  value       = module.iam_irsa.alb_controller_role_arn
}

# ECR

output "ecr_repository_urls" {
  description = "Map of ECR repository name to URL"
  value       = module.ecr.repository_urls
}

# ALB

output "alb_dns_names" {
  description = "Map of ALB key to DNS name"
  value       = { for k, v in module.alb : k => v.alb_dns_name }
}

# CLOUDFRONT

output "cloudfront_domain_names" {
  description = "Map of CloudFront distribution key to domain name"
  value       = { for k, v in module.cloudfront : k => v.distribution_domain_name }
}

# RDS

output "rds_endpoints" {
  description = "Map of RDS instance key to endpoint (host:port)"
  value       = { for k, v in module.rds : k => v.db_endpoint }
}

output "rds_db_names" {
  description = "Map of RDS instance key to database name — required for app connection config"
  value       = { for k, v in module.rds : k => v.db_name }
}

output "rds_secret_arns" {
  description = "Map of RDS instance key to Secrets Manager ARN"
  value       = { for k, v in module.rds : k => v.secret_arn }
}

# CLOUDWATCH / OBSERVABILITY

output "cloudwatch_eks_log_group_names" {
  description = "Map of CloudWatch key to EKS log group name"
  value       = { for k, v in module.cloudwatch : k => v.eks_log_group_name }
}

output "cloudwatch_sns_topic_arns" {
  description = "Map of CloudWatch key to alarms SNS topic ARN"
  value       = { for k, v in module.cloudwatch : k => v.sns_topic_arn }
}

# HELM ADD-ONS

output "metrics_server_release_name" {
  description = "Helm release name for Metrics Server"
  value       = module.eks_addons_helm.metrics_server_release_name
}

output "envoy_gateway_release_name" {
  description = "Helm release name for Envoy Gateway"
  value       = module.eks_addons_helm.envoy_gateway_release_name
}

output "velero_release_name" {
  description = "Helm release name for Velero"
  value       = module.eks_addons_helm.velero_release_name
}
