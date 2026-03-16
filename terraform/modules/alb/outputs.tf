output "alb_arn" {
  value = aws_lb.main.arn
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_arn_suffix" {
  value = aws_lb.main.arn_suffix
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

output "target_group_arns" {
  description = "Map of target group keys to their ARNs"
  value       = { for k, v in aws_lb_target_group.this : k => v.arn }
}

output "listener_arns" {
  description = "Map of listener keys to their ARNs"
  value       = { for k, v in aws_lb_listener.this : k => v.arn }
}
