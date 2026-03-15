output "security_group_ids" {
  description = "Map of all security group IDs by key"
  value       = { for k, sg in aws_security_group.main : k => sg.id }
}
