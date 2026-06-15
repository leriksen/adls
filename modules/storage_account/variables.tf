variable "resource_group_name" {
  type = string
}

variable "sequence_no" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "sftp_enabled" {
  type    = bool
  default = false
}
