variable "environment" {
  type    = string
  default = "dev"
}

variable "storage" {
  description = "ADLS Gen2 storage accounts to provision, each with queues, containers, and paths."
  type = list(object({
    sequence_no = string
    snowflake_sp = optional(string)
    sa_integration_sp = optional(string)
    notification_integration_sp = optional(string)
    system_topic_name = optional(string)
    queues = optional(list(object({
      name = string
      type = string # "queue" or "dlq"
    })), [])
    containers = list(object({
      container_name = string
      acl = optional(list(object({
        scope       = string
        id          = string
        permissions = string
        type        = string
      })), [])
    }))
    paths = list(object({
      container_name = string
      path_name      = string
      resource_type  = optional(string, "directory")
      acl = optional(list(object({
        scope       = string
        id          = string
        permissions = string
        type        = string
      })), [])
    }))
  }))
}

# variable "pguser" {
#   type = string
# }
#
#
# variable "pgpassword" {
#   type = string
# }
#
# variable "AZDO_ORG_SERVICE_URL" {
#   type = string
# }
#
# variable "AZDO_PERSONAL_ACCESS_TOKEN" {
#   type = string
# }