# ALB Module

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  # Truncate name prefix to fit: AWS allows 32 chars for target group names
  # Format: <prefix>-<tg_key>  e.g. "n3t-dev-web" (max 32 chars)
  name_prefix = substr(
    "${var.project_name}-${var.environment}",
    0,
    min(length("${var.project_name}-${var.environment}"), 20)
  )
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2               = var.enable_http2
  idle_timeout               = var.idle_timeout

  dynamic "access_logs" {
    for_each = var.enable_access_logs && var.access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      enabled = true
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

# Target Groups (dynamic — defined per ALB in tfvars)
resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  # Names must be <= 32 chars. Format: <name_prefix>-<key> truncated.
  name        = substr("${local.name_prefix}-${each.key}", 0, 32)
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = try(each.value.health_check.healthy_threshold, 3)
    unhealthy_threshold = try(each.value.health_check.unhealthy_threshold, 3)
    timeout             = try(each.value.health_check.timeout, 5)
    interval            = try(each.value.health_check.interval, 30)
    path                = try(each.value.health_check.path, "/")
    matcher             = try(each.value.health_check.matcher, "200")
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}"
  })
}

# Default Listener — forwards to the target group marked default = true
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.listener_port
  protocol          = var.listener_protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[var.default_target_group].arn
  }

  tags = local.common_tags
}

# Path-based routing rules for non-default target groups
resource "aws_lb_listener_rule" "path_routing" {
  for_each = {
    for k, v in var.target_groups : k => v
    if try(v.path_patterns, null) != null && k != var.default_target_group
  }

  listener_arn = aws_lb_listener.http.arn
  priority     = try(each.value.priority, 100)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }

  tags = local.common_tags
}
