locals {
  account_name        = "gl-latam"
  account_id          = "517142901316"

  tf_state_bucket_name     = "gl-tfstate-${local.account_name}"
  tf_state_key_prefix      = "tf-state-${local.account_name}"
  tf_state_lock_table_name = "tf-state-${local.account_name}-locks"

  tags = {
  }
}
