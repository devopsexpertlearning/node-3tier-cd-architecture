locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  s3_buckets = {
    for k, v in var.s3_buckets : k => merge(v, {
      name = "${v.name}-${random_string.s3_suffix.result}"
    })
  }

  rds_instances            = var.rds_instances
  albs                     = var.albs
  cloudfront_distributions = var.cloudfront_distributions

  alb_tgs = flatten([
    for alb_key, alb in local.albs : [
      for tg_key, tg in alb.target_groups : {
        alb_key = alb_key
        tg_key  = tg_key
        port    = tg.port
      }
    ]
  ])
}

resource "random_string" "s3_suffix" {
  length  = 8
  special = false
  upper   = false
}

data "aws_elb_service_account" "main" {}
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "alb_logs" {
  for_each = local.s3_buckets

  bucket = module.s3_bucket[each.key].bucket_id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.main.arn }
        Action    = "s3:PutObject"
        Resource  = "${module.s3_bucket[each.key].bucket_arn}/AWSLogs/*"
      }
    ]
  })
}

# Allow EKS Fargate pods (auto-created cluster SG) to reach RDS on port 5432
resource "aws_vpc_security_group_ingress_rule" "rds_from_eks_cluster" {
  for_each = local.rds_instances

  security_group_id            = module.security_groups.security_group_ids[each.value.security_group_key]
  referenced_security_group_id = module.eks.cluster_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"

  tags = local.common_tags

  depends_on = [module.eks, module.security_groups]
}

# Allow ALB to reach EKS Fargate pods via the auto-created cluster SG
# (Fargate pods use cluster_security_group_id, not additional SGs)
resource "aws_vpc_security_group_ingress_rule" "eks_cluster_from_albs_tgs" {
  for_each = {
    for tg in local.alb_tgs : "${tg.alb_key}-${tg.tg_key}" => tg
  }

  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = module.security_groups.security_group_ids[local.albs[each.value.alb_key].security_group_key]
  from_port                    = each.value.port
  to_port                      = each.value.port
  ip_protocol                  = "tcp"

  depends_on = [module.eks, module.security_groups]
}

# 1. VPC
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = ["${var.aws_region}a", "${var.aws_region}b"]
  single_nat_gateway   = var.single_nat_gateway
  tags                 = var.tags
}

# 2. Security Groups
module "security_groups" {
  source = "../../modules/security-groups"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = var.vpc_cidr
  security_groups = var.security_groups
  tags            = var.tags
}

# 3. IAM
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

module "iam_irsa" {
  source = "../../modules/iam"

  project_name               = var.project_name
  environment                = "${var.environment}-irsa"
  eks_oidc_provider_arn      = module.eks.oidc_provider_arn
  eks_oidc_provider_url      = module.eks.oidc_provider_url
  create_alb_controller_role = true
  tags                       = var.tags
}

# 4. EKS
module "eks" {
  source = "../../modules/eks"

  project_name            = var.project_name
  environment             = var.environment
  subnet_ids              = module.vpc.private_subnet_ids
  security_group_ids      = [module.security_groups.security_group_ids["eks-cluster"]]
  cluster_role_arn        = module.iam.eks_cluster_role_arn
  kubernetes_version      = var.kubernetes_version
  endpoint_public_access  = var.eks_endpoint_public_access
  endpoint_private_access = var.eks_endpoint_private_access
  enabled_log_types       = var.eks_enabled_log_types
  addons                  = var.eks_addons
  tags                    = var.tags
}

# 5. EKS Fargate Profile
module "fargate_profile" {
  source = "../../modules/fargate-profile"

  project_name                   = var.project_name
  environment                    = var.environment
  cluster_name                   = module.eks.cluster_name
  fargate_pod_execution_role_arn = module.iam.fargate_pod_execution_role_arn
  subnet_ids                     = module.vpc.private_subnet_ids
  profiles                       = var.fargate_profiles
  addons                         = var.eks_addons
  tags                           = var.tags

  depends_on = [module.eks, module.iam]
}

# EKS cluster auth for Helm provider
data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name
}

# 6. EKS Helm Addons
module "eks_addons_helm" {
  source = "../../modules/eks-addons-helm"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority
  cluster_token          = data.aws_eks_cluster_auth.eks.token

  enable_metrics_server        = var.enable_metrics_server
  metrics_server_chart_version = var.metrics_server_chart_version

  enable_envoy_gateway        = var.enable_envoy_gateway
  envoy_gateway_chart_version = var.envoy_gateway_chart_version
  enable_velero               = var.enable_velero
  velero_chart_version        = var.velero_chart_version
  velero_backup_s3_bucket     = module.s3_bucket["velero-backup"].bucket_id
  velero_iam_role_arn         = module.iam_irsa.fargate_pod_execution_role_arn
  enable_velero_schedule      = var.enable_velero_schedule

  enable_fargate_logging     = var.enable_fargate_logging
  fargate_log_retention_days = var.fargate_log_retention_days

  enable_adot_collector        = var.enable_adot_collector
  adot_collector_replicas      = var.adot_collector_replicas
  adot_collector_chart_version = var.adot_collector_chart_version
  adot_iam_role_arn            = module.iam_irsa.fargate_pod_execution_role_arn

  enable_alb_controller        = var.enable_alb_controller
  alb_controller_chart_version = var.alb_controller_chart_version
  alb_controller_iam_role_arn  = module.iam_irsa.alb_controller_role_arn
  vpc_id                       = module.vpc.vpc_id

  tags = var.tags
}

# 7. ECR
module "ecr" {
  source = "../../modules/ecr"

  project_name         = var.project_name
  environment          = var.environment
  repository_names     = var.ecr_repository_names
  image_retention_days = var.ecr_image_retention_days
  tags                 = var.tags
}

# 8. S3
module "s3_bucket" {
  source   = "../../modules/s3"
  for_each = local.s3_buckets

  project_name      = var.project_name
  environment       = var.environment
  bucket_name       = each.value.name
  enable_versioning = each.value.enable_versioning
  force_destroy     = each.value.force_destroy

  lifecycle_rules = each.value.expiration_days > 0 ? [
    {
      id         = "expire-old-logs"
      expiration = [{ days = each.value.expiration_days }]
    }
  ] : []

  tags = var.tags
}

# 9. RDS
module "rds" {
  source   = "../../modules/rds"
  for_each = local.rds_instances
  providers = {
    aws.replica = aws.replica
  }

  project_name                                                  = "${var.project_name}-${each.key}"
  environment                                                   = var.environment
  security_group_id                                             = module.security_groups.security_group_ids[each.value.security_group_key]
  private_subnet_ids                                            = module.vpc.private_subnet_ids
  db_name                                                       = each.value.db_name
  db_username                                                   = each.value.db_username
  db_instance_class                                             = each.value.db_instance_class
  allocated_storage                                             = each.value.allocated_storage
  max_allocated_storage                                         = each.value.max_allocated_storage
  db_engine_version                                             = each.value.engine_version
  multi_az                                                      = each.value.multi_az
  backup_retention_period                                       = each.value.backup_retention_period
  backup_window                                                 = each.value.backup_window
  maintenance_window                                            = each.value.maintenance_window
  deletion_protection                                           = each.value.deletion_protection
  skip_final_snapshot                                           = each.value.skip_final_snapshot
  performance_insights_enabled                                  = each.value.performance_insights_enabled
  enable_automated_backups_replication                          = each.value.enable_automated_backups_replication
  automated_backups_replication_retention_period                = each.value.automated_backups_replication_retention_period
  automated_backups_replication_kms_key_deletion_window_in_days = each.value.automated_backups_replication_kms_key_deletion_window_in_days
  secret_recovery_window_in_days                                = each.value.secret_recovery_window_in_days
  delete_automated_backups                                      = each.value.delete_automated_backups
  tags                                                          = var.tags
}

# 10. ALB
module "alb" {
  source   = "../../modules/alb"
  for_each = local.albs

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.security_group_ids[each.value.security_group_key]

  internal                   = each.value.internal
  enable_access_logs         = each.value.enable_access_logs
  access_logs_bucket         = module.s3_bucket[each.value.logs_bucket_key].bucket_id
  enable_deletion_protection = each.value.enable_deletion_protection
  enable_http2               = each.value.enable_http2
  idle_timeout               = each.value.idle_timeout
  listeners = {
    for k, v in each.value.listeners : k => merge(
      { for kk, vv in v : kk => vv if kk != "certificate_id" },
      try(v.certificate_id, null) != null ? {
        certificate_arn = "arn:aws:acm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:certificate/${v.certificate_id}"
      } : {}
    )
  }
  default_target_group = each.value.default_target_group

  target_groups = each.value.target_groups
  tags          = var.tags
}

# 11. CloudFront
module "cloudfront" {
  source   = "../../modules/cloudfront"
  for_each = local.cloudfront_distributions

  project_name = "${var.project_name}-${each.key}"
  environment  = var.environment
  alb_dns_name = module.alb[each.value.alb_key].alb_dns_name

  price_class                    = each.value.price_class
  enabled                        = each.value.enabled
  is_ipv6_enabled                = each.value.is_ipv6_enabled
  wait_for_deployment            = each.value.wait_for_deployment
  origin_protocol_policy         = each.value.origin_protocol_policy
  default_viewer_protocol_policy = each.value.default_viewer_protocol_policy
  default_cache_ttl              = each.value.default_cache_ttl
  static_cache_behaviors         = each.value.static_cache_behaviors
  aliases         = try(each.value.aliases, [])

  # CloudFront ACM certs must be in us-east-1 regardless of deployment region
  certificate_arn = try(each.value.certificate_id, "") != "" ? "arn:aws:acm:us-east-1:${data.aws_caller_identity.current.account_id}:certificate/${each.value.certificate_id}" : ""

  tags = var.tags
}

# 12. CloudWatch
module "cloudwatch" {
  source   = "../../modules/cloudwatch"
  for_each = local.albs

  project_name     = "${var.project_name}-${each.key}"
  environment      = var.environment
  aws_region       = var.aws_region
  eks_cluster_name = module.eks.cluster_name
  alb_arn_suffix   = module.alb[each.key].alb_arn_suffix

  rds_instance_id = length(local.rds_instances) > 0 ? module.rds[keys(local.rds_instances)[0]].db_instance_id : ""

  create_rds_alarms  = var.cloudwatch_create_rds_alarms
  create_alb_alarms  = var.cloudwatch_create_alb_alarms
  log_retention_days = var.cloudwatch_log_retention_days
  alarm_email        = var.alarm_email

  tags = var.tags
}