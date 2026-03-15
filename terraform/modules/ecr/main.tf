# ECR Module

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ECR Repositories
resource "aws_ecr_repository" "repos" {
  for_each             = toset(var.repository_names)
  name                 = "${var.project_name}-${var.environment}-${each.key}"
  image_tag_mutability = var.image_tag_mutability
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-${each.key}"
  })
}

# Lifecycle policy — expire images older than retention days
resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = toset(var.repository_names)
  repository = aws_ecr_repository.repos[each.key].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire images older than ${var.image_retention_days} days"
      selection = {
        tagStatus   = "any"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.image_retention_days
      }
      action = {
        type = "expire"
      }
    }]
  })
}
