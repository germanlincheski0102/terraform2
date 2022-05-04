variable "name_prefix" {}
variable "service_account" {}
variable "cluster_id" {}
variable "tags" {
  type = map(string)
}
variable "provider_urls" {
  type = list(string)
}
variable "primary_policy" {
  type    = string
  default = null
}
variable "additional_policy_arns" {
  type    = list(string)
  default = []
}
variable "oidc_fully_qualified_subjects" {
  type = list(string)
}
variable "create_role" {
  type    = bool
  default = true
}
variable "create_security_group" {
  type    = bool
  default = false
}
variable "egress_with_cidr_blocks" {
  type = list(map(string))
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}
variable "vpc_id" {
  default = null
  type    = string
}
