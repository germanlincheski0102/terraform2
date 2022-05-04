resource "aws_iam_policy" "primary_policy" {
  count       = var.primary_policy != null ? 1 : 0
  name_prefix = var.name_prefix
  description = "Primary policy for ${var.service_account} service account in cluster ${var.cluster_id}"
  tags        = var.tags
  policy      = var.primary_policy
}

module "role" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "4.6.0"
  create_role                   = var.create_role
  role_name_prefix              = var.name_prefix
  tags                          = merge(var.tags, { Description = "Role with OIDC for attaching policies to EKS ${var.service_account} service account in cluster ${var.cluster_id}" })
  provider_urls                 = var.provider_urls
  role_policy_arns              = var.primary_policy != null ? concat([aws_iam_policy.primary_policy[0].arn], var.additional_policy_arns) : var.additional_policy_arns
  number_of_role_policy_arns    = var.primary_policy != null ? length(var.additional_policy_arns) + 1 : length(var.additional_policy_arns)
  oidc_fully_qualified_subjects = var.oidc_fully_qualified_subjects
}

module "security_group" {
  count       = var.create_security_group ? 1 : 0
  source      = "terraform-aws-modules/security-group/aws"
  version     = "4.7.0"
  name        = "sa-${var.service_account}-${var.cluster_id}"
  description = "Associated with EKS service account ${var.service_account} in cluster ${var.cluster_id}"
  vpc_id      = var.vpc_id
  tags        = var.tags

  # Egress defaults to any from any, but ingress should
  # never be allowed - that's what k8s ingress is for!
  egress_with_cidr_blocks = var.egress_with_cidr_blocks
}
