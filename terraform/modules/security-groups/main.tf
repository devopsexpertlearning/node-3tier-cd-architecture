locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  # Flatten all ingress rules with their parent SG key
  ingress_rules = flatten([
    for sg_key, sg in var.security_groups : [
      for idx, rule in try(sg.ingress_rules, []) : {
        key               = "${sg_key}-in-${idx}"
        sg_key            = sg_key
        from_port         = rule.from_port
        to_port           = rule.to_port
        protocol          = rule.protocol
        cidr_ipv4         = try(rule.cidr_ipv4, "")
        referenced_sg_key = try(rule.referenced_sg_key, "")
      }
    ]
  ])

  # Flatten all egress rules with their parent SG key
  egress_rules = flatten([
    for sg_key, sg in var.security_groups : [
      for idx, rule in try(sg.egress_rules, []) : {
        key       = "${sg_key}-out-${idx}"
        sg_key    = sg_key
        protocol  = rule.protocol
        cidr_ipv4 = try(rule.cidr_ipv4, "0.0.0.0/0")
      }
    ]
  ])
}

# Create all security groups dynamically from the map
resource "aws_security_group" "main" {
  for_each    = var.security_groups
  name        = "${var.project_name}-${var.environment}-${each.key}-sg"
  description = try(each.value.description, "Managed by Terraform")
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-${each.key}-sg"
  })
}

# Create ingress rules (external, no inline blocks)
resource "aws_vpc_security_group_ingress_rule" "main" {
  for_each = {
    for rule in local.ingress_rules : rule.key => rule
  }

  security_group_id            = aws_security_group.main[each.value.sg_key].id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.protocol
  cidr_ipv4                    = each.value.cidr_ipv4 != "" ? (each.value.cidr_ipv4 == "vpc_cidr" ? var.vpc_cidr : each.value.cidr_ipv4) : null
  referenced_security_group_id = each.value.referenced_sg_key != "" ? aws_security_group.main[each.value.referenced_sg_key].id : null
}

# Create egress rules (external, no inline blocks)
resource "aws_vpc_security_group_egress_rule" "main" {
  for_each = {
    for rule in local.egress_rules : rule.key => rule
  }

  security_group_id = aws_security_group.main[each.value.sg_key].id
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr_ipv4
}
