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

# Lifecycle policy to keep only last 10 images
resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = toset(var.repository_names)
  repository = aws_ecr_repository.repos[each.key].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
