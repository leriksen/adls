variable "storage_account_id" {
  type = string
}

variable "queues" {
  type = list(object({
    name = string
    type = string
  }))
}
