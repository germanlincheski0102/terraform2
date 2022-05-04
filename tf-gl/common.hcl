locals {

  # The following assumes this repo is stored in gitlsb and prefixed
  # with "tf-", and cloned over git: (not https://)
  repo_url                 = trimspace(run_cmd("--terragrunt-quiet", "git", "config", "--get", "remote.origin.url"))
  repo_parts               = regex(".*gitlab-art.globallogic.com.ar:(.*\\/tf-)(.*)[.]git", local.repo_url)
  project                  = local.repo_parts[1]
  repo_https_url           = "https://gitlab-art.globallogic.com.ar/${local.repo_parts[0]}${local.project}"
  org_prefix               = "gllatam"
  org_tld                  = "globallogic.com.ar"
  tf_state_bucket_name     = "${local.org_prefix}-tfstate-${local.project}"
  tf_state_key_prefix      = "tf-state-${local.project}"
  tf_state_lock_table_name = "tf-state-${local.project}-locks"

  tags = {
    Terraform        = "true"
    TerraformRepo    = local.repo_https_url
    TerraformRepoGit = local.repo_url
  }

  record_defaults = {
    type                             = ""
    prefix                           = ""
    set_identifier                   = ""
    health_check_id                  = ""
    alias                            = ""
    failover_routing_policy          = []
    geolocation_routing_policy       = []
    latency_routing_policy           = []
    weighted_routing_policy          = []
    multivalue_answer_routing_policy = false
    allow_overwrite                  = false
    ttl                              = ""
    values                           = []
  }
}