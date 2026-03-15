locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# -----------------------------------------------------------------------------
# LOG GROUPS
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/eks/${var.eks_cluster_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "app_web" {
  name              = "/app/${var.project_name}/${var.environment}/web"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "app_api" {
  name              = "/app/${var.project_name}/${var.environment}/api"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# New log groups for Fargate observability
resource "aws_cloudwatch_log_group" "fargate" {
  name              = "/aws/eks/${var.eks_cluster_name}/fargate"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "container_insights" {
  name              = "/aws/containerinsights/${var.eks_cluster_name}/performance"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# -----------------------------------------------------------------------------
# DASHBOARD
# -----------------------------------------------------------------------------

data "aws_region" "current" {}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1 — ALB (Web + API tier traffic)
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "ALB Request Count"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ALB Response Time (avg)"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_ELB_4XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = data.aws_region.current.name
          title  = "ALB HTTP Error Codes"
        }
      },
      # Row 2 — Container tier (EKS Fargate CPU + Memory)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", "ClusterName", var.eks_cluster_name],
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", var.eks_cluster_name]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "EKS CPU Utilization (%)"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["ContainerInsights", "pod_memory_utilization", "ClusterName", var.eks_cluster_name],
            ["ContainerInsights", "node_memory_utilization", "ClusterName", var.eks_cluster_name]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "EKS Memory Utilization (%)"
        }
      },
      # Row 3 — RDS (DB tier health)
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "RDS CPU Utilization (%)"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 12
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.rds_instance_id]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "RDS Free Storage (bytes)"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 12
        width  = 8
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_instance_id]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "RDS Active Connections"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ALARMS & SNS
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "alarms" {
  count = var.alarm_email != "" ? 1 : 0
  name  = "${var.project_name}-${var.environment}-alarms"
  tags  = local.common_tags
}

resource "aws_sns_topic_subscription" "alarm_email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ALB Alarms
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count               = var.create_alb_alarms && var.alarm_email != "" ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB 5xx errors exceed threshold"
  alarm_actions       = [aws_sns_topic.alarms[0].arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "alb_latency" {
  count               = var.create_alb_alarms && var.alarm_email != "" ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-alb-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "ALB target response time is too high (> 1s)"
  alarm_actions       = [aws_sns_topic.alarms[0].arn]
  
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
  tags = local.common_tags
}

# RDS Alarms
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count               = var.create_rds_alarms && var.alarm_email != "" ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization > 80%"
  alarm_actions       = [aws_sns_topic.alarms[0].arn]
  
  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  count               = var.create_rds_alarms && var.alarm_email != "" ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-rds-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5000000000 # 5 GB
  alarm_description   = "RDS free storage space below 5GB"
  alarm_actions       = [aws_sns_topic.alarms[0].arn]
  
  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }
  tags = local.common_tags
}
