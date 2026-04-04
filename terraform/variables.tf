variable "environment" {
  type    = string
  default = "dev"
}

variable "storage" {
  description = <<-EOT
    List of ADLS Gen2 storage accounts to provision. Each entry defines one storage account and its associated resources.

    Attributes:
      sequence_no                   - Numeric suffix used to name the storage account and related resources (e.g. "01" → argdl01).
      snowflake_sp                  - (optional) Object ID of the Snowflake service principal; grants Storage Blob Data Contributor.
      sa_integration_sp             - (optional) Object ID of the SA integration service principal; grants Storage Blob Data Contributor.
      notification_integration_sp   - (optional) Object ID of the notification integration SP; grants Storage Queue Data Contributor on "queue"-typed queues only.
      system_topic_name             - (optional) Name of the existing Event Grid system topic to subscribe to for BlobCreated events.
      sa_system_topic_principal     - (optional) Object ID of the Event Grid system topic managed identity; required for EG queue sender and deadletter blob contributor role assignments.
      queues                        - (optional) List of storage queues to create. Each queue has a name and a type: "queue" (EG delivery target) or "deadletter" (failed-message inspection).
      containers                    - List of ADLS Gen2 filesystem containers to create, each with an optional ACL.
      paths                         - List of directory paths to create within containers, each with an optional ACL.
  EOT
  type = list(object({
    sequence_no = string
    snowflake_sp = optional(string)
    sa_integration_sp = optional(string)
    notification_integration_sp = optional(string)
    system_topic_name = optional(string)
    sa_system_topic_principal = optional(string)
    queues = optional(list(object({
      name = string
      type = string # "queue" or "deadletter"
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