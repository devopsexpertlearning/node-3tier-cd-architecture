output "fargate_profile_ids" {
  description = "A map of Fargate Profile IDs"
  value       = { for k, v in aws_eks_fargate_profile.this : k => v.id }
}

output "fargate_profile_arns" {
  description = "A map of Fargate Profile ARNs"
  value       = { for k, v in aws_eks_fargate_profile.this : k => v.arn }
}
