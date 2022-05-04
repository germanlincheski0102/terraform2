locals {
  namespace_vars = read_terragrunt_config(find_in_parent_folders("namespace.hcl"))

  tags = merge(
    local.namespace_vars.locals.tags,
    local.additional_tags
  )

  additional_tags = {
  }

  service_account = "flux"
}

include {
  path = find_in_parent_folders()
}

terraform {
  source = "git@gitlab-art.globallogic.com.ar:practices/devops/terraform/tf-gl-main.git//0.14.x/eks-service-account?ref=eks-service-account-0.14.x-0.1.0"
}

dependency "eks" {
  config_path = "../../../../eks"
}

// In this example the policy needs a KMS ARN which it gets here
dependency "kms" {
  config_path = "../../../../kms/devops"
}

inputs = {
  // name_prefix is the name given to role and policy in IAM
  name_prefix                   = "${local.service_account}-${local.namespace_vars.locals.namespace}"
  // service_account must match actual service account name in k8s
  service_account               = local.service_account
  cluster_id                    = dependency.eks.outputs.cluster_id
  tags                          = local.tags
  provider_urls                 = [dependency.eks.outputs.cluster_oidc_issuer_url]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.namespace_vars.locals.namespace}:${local.service_account}"]

  # Define a new custom policy, if needed. Comment out if not needed.
  primary_policy = templatefile("${get_terragrunt_dir()}/policy.json.tpl", {
    kms_arn = dependency.kms.outputs.arn
  })

  // Add existing policies if desired
  additional_policy_arns = []

  # Next 2 lines are for security group that can be associated via k8s securityGroupPolicy. Comment out if not needed
  create_security_group = true
  vpc_id                = dependency.vpc.outputs.vpc_id
}
