locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  tags = merge(
    local.env_vars.locals.tags,
    local.additional_tags
  )
  env = local.env_vars.locals.env
  # Customize if needed
  additional_tags = {
  }
}

include {
  path = find_in_parent_folders()
}

prevent_destroy = true

terraform {
  source = "./_module"
  extra_arguments "init_args" {
    commands = [
      "init"
    ]
    arguments = [
    ]
  }
}

inputs = {
  budget_name            = "gl-monthly-budget"
  budget_money_limit     = 140
  budget_mail_subscriber = ["angel.cancio@globallogic.com", "gabriel.arango@globallogic.com"]
  tags                   = local.tags
}