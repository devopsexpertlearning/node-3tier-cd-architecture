project_name = "node-3tier"
environment  = "dev"
aws_region   = "us-east-1"
vpc_cidr     = "10.0.0.0/16"

public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
single_nat_gateway   = true

kubernetes_version          = "1.33"
eks_endpoint_public_access  = true
eks_endpoint_private_access = true
eks_enabled_log_types       = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

tags = {
  CostCenter = "engineering"
  Team       = "devops"
}


# EKS Add-ons natively managed by Terraform
eks_addons = {
  "vpc-cni" = {
    version                     = "v1.21.1-eksbuild.3"
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "OVERWRITE"
  }
  "coredns" = {
    version                     = "v1.13.2-eksbuild.1"
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "OVERWRITE"
  }
  "kube-proxy" = {
    version                     = "v1.33.8-eksbuild.4"
    resolve_conflicts_on_create = "OVERWRITE"
    resolve_conflicts_on_update = "OVERWRITE"
  }
}
ecr_repository_names     = ["web", "api"]
ecr_image_retention_days = 1

# EKS Helm Add-ons (Envoy, Velero)
enable_metrics_server        = true
metrics_server_chart_version = "3.13.0"

enable_envoy_gateway        = false
envoy_gateway_chart_version = "v1.7.1"

enable_velero          = true
velero_chart_version   = "11.4.0"
enable_velero_schedule = false

enable_alb_controller        = true
alb_controller_chart_version = "3.0.0"

# Fargate Observability for monitoring
enable_fargate_logging       = true
fargate_log_retention_days   = 30
enable_adot_collector        = true
adot_collector_chart_version = "0.108.0"
adot_collector_replicas      = 1

# Fargate Profiles
fargate_profiles = {
  k8s-core = {
    selectors = [
      { namespace = "default" },
      { namespace = "kube-system" },
      { namespace = "envoy-gateway-system" },
      { namespace = "velero" },
      { namespace = "amazon-cloudwatch" }
    ]
  }
  web-api = {
    selectors = [
      { namespace = "node-3tier-app" }
    ]
  }
  k8s-logs-monitoring = {
    selectors = [
      { namespace = "aws-observability" },
      { namespace = "opentelemetry" }
    ]
  }
}

# Security Groups
security_groups = {
  appdb-rds = {
    description   = "RDS Security Group for appdb"
    ingress_rules = []
    egress_rules = [
      {
        cidr_ipv4 = "0.0.0.0/0"
        protocol  = "-1"
      }
    ]
  }
  eks-cluster = {
    description = "EKS Cluster Security Group"
    ingress_rules = [
      {
        cidr_ipv4         = "vpc_cidr"
        from_port         = 443
        protocol          = "tcp"
        referenced_sg_key = ""
        to_port           = 443
      }
    ]
    egress_rules = [
      {
        cidr_ipv4 = "0.0.0.0/0"
        protocol  = "-1"
      }
    ]
  }
  web-api-alb = {
    description = "ALB Security Group for web-api"
    ingress_rules = [
      {
        cidr_ipv4         = "0.0.0.0/0"
        from_port         = 80
        protocol          = "tcp"
        referenced_sg_key = ""
        to_port           = 80
      },
      {
        cidr_ipv4         = "0.0.0.0/0"
        from_port         = 443
        protocol          = "tcp"
        referenced_sg_key = ""
        to_port           = 443
      }
    ]
    egress_rules = [
      {
        cidr_ipv4 = "0.0.0.0/0"
        protocol  = "-1"
      }
    ]
  }
}

rds_instances = {
  appdb = {
    allocated_storage                                             = 20
    automated_backups_replication_kms_key_deletion_window_in_days = 7
    automated_backups_replication_retention_period                = 3
    backup_retention_period                                       = 7
    backup_window                                                 = "03:00-04:00"
    db_instance_class                                             = "db.t3.micro"
    db_name                                                       = "appdb"
    db_username                                                   = "dbadmin"
    delete_automated_backups                                      = true
    deletion_protection                                           = false
    enable_automated_backups_replication                          = false
    engine_version                                                = "17.2"
    maintenance_window                                            = "sun:04:00-sun:05:00"
    max_allocated_storage                                         = 100
    multi_az                                                      = false
    performance_insights_enabled                                  = true
    secret_recovery_window_in_days                                = 0
    security_group_key                                            = "appdb-rds"
    skip_final_snapshot                                           = true
    rds_automated_backups_replication_region                      = null # "ap-south-1"
  }
}

# S3 Buckets
s3_buckets = {
  alb-logs = {
    name              = "node-3tier-dev-alb-logs"
    enable_versioning = false
    force_destroy     = true
    expiration_days   = 30
  }
  velero-backup = {
    name              = "node-3tier-dev-velero-backup"
    enable_versioning = false
    force_destroy     = true
    expiration_days   = 30
  }
}

albs = {
  web-api-alb = {
    default_target_group       = "web"
    enable_access_logs         = true
    enable_deletion_protection = false
    enable_http2               = true
    idle_timeout               = 60
    internal                   = false
    logs_bucket_key            = "alb-logs"
    security_group_key         = "web-api-alb"
    listeners = {
      http = {
        port              = 80
        protocol          = "HTTP"
        redirect_to_https = true
      }
      https = {
        port           = 443
        protocol       = "HTTPS"
        certificate_id = "2dc67818-4396-488d-b14d-e2e1124b6bfb"
      }
    }
    target_groups = {
      web = {
        health_check = {
          healthy_threshold   = 3
          interval            = 30
          matcher             = "200"
          path                = "/"
          timeout             = 5
          unhealthy_threshold = 3
        }
        port = 3000
      }
    }
  }
}

cloudfront_distributions = {
  web-api = {
    alb_key                        = "web-api-alb"
    default_cache_ttl              = { default = 0, max = 86400, min = 0 }
    default_viewer_protocol_policy = "redirect-to-https"
    enabled                        = true
    is_ipv6_enabled                = true
    origin_protocol_policy         = "https-only"
    price_class                    = "PriceClass_100"
    aliases                        = ["samplesite.devopsexpert.work.gd"]
    certificate_id                 = "2dc67818-4396-488d-b14d-e2e1124b6bfb"
    static_cache_behaviors = [
      {
        default_ttl            = 86400
        max_ttl                = 604800
        min_ttl                = 3600
        path_pattern           = "/stylesheets/*"
        viewer_protocol_policy = "redirect-to-https"
      },
      {
        default_ttl            = 86400
        max_ttl                = 604800
        min_ttl                = 3600
        path_pattern           = "/images/*"
        viewer_protocol_policy = "redirect-to-https"
      }
    ]
    wait_for_deployment = true
  }
}

cloudwatch_create_rds_alarms  = true
cloudwatch_create_alb_alarms  = true
cloudwatch_log_retention_days = 30
alarm_email                   = "mail@devopsexpert.work.gd"
