variable "alias" {
}
variable "description" {
}
variable "enable_key_rotation" {
  type = bool
}
variable "tags" {
  type = map(string)
}
variable "policy" {
}
variable "deletion_window_in_days" {
  default = "30"
}
variable "sops_file" {
}
