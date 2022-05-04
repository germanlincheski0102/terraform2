output "role_arn" {
  value = module.role.iam_role_arn
}
output "security_group_id" {
  value = var.create_security_group ? module.security_group[0].security_group_id : null
}
