output "eks_log_group_name" {
  value = aws_cloudwatch_log_group.eks.name
}

output "web_log_group_name" {
  value = aws_cloudwatch_log_group.app_web.name
}

output "api_log_group_name" {
  value = aws_cloudwatch_log_group.app_api.name
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}

output "sns_topic_arn" {
  value = length(aws_sns_topic.alarms) > 0 ? aws_sns_topic.alarms[0].arn : ""
}
