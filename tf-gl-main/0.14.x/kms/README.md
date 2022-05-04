Example:
```
locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env              = local.environment_vars.locals.environment
  common_vars      = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  common_tags      = local.common_vars.locals.tags
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  account_id       = local.account_vars.locals.account_id

  tags = merge(local.common_tags, {
    Environment = local.env
  })
}

include {
  path = find_in_parent_folders()
}

terraform {
  source = "_module"
}


dependency "eks" {
  config_path = "../eks"
}

inputs = {
  alias               = "alias/marconi-secrets"
  description         = "Used for encrypting marconi secrets"
  enable_key_rotation = true
  tags                = local.tags

  policy = <<POLICY
{
    "Id": "key-consolepolicy-3",
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${local.account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Principal": {
            "AWS": [
    "${dependency.eks.outputs.worker_iam_role_arn}"
            ]
            },
            "Action": [
            "kms:Decrypt"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}
```
