variable "environment" {
  type    = string
  default = "dev"
}

variable "storage" {
  description = <<-EOT
    List of ADLS Gen2 storage accounts to provision. Each entry defines one storage account and its associated resources.

    sequence_no                 - Numeric suffix used to name the storage account and related resources (e.g. "01" → argdl01).
    snowflake_sp                - (optional) Object ID of the Snowflake service principal; grants Storage Blob Data Contributor.
    sa_integration_sp           - (optional) Object ID of the SA integration service principal; grants Storage Blob Data Contributor.
    notification_integration_sp - (optional) Object ID of the notification integration SP; grants Storage Queue Data Contributor on "queue"-typed queues only.
    system_topic_name           - (optional) Name of the existing Event Grid system topic to subscribe to for BlobCreated events.
    sa_system_topic_principal   - (optional) Object ID of the Event Grid system topic managed identity; required for EG queue sender and deadletter role assignments.
    pep_connection              - (optional) Private endpoint connection to approve or deny.
      pep_name          - Name of the private endpoint connection.
      resource_id       - Resource ID of the resource the PEP is attached to.
      approve           - true to approve the connection; false to deny it.
      delete_connection - (optional) If false, passed to pep-deny as rejection_only. Defaults to true.

    queues (optional) - Storage queues to create.
      name                    - Queue name.
      type                    - "queue" (EG delivery target) or "deadletter" (failed-message inspection).
      sa_deadletter_container - (optional) Blob container name to use as the EG dead-letter destination for this queue. Not required for "deadletter"-typed queues.
      retry_policy            - (optional) EG retry policy. Defaults to 30 attempts / 1440 min TTL.
      included_event_types    - (optional) Event types to subscribe to. Default: ["Microsoft.Storage.BlobCreated"].
      subject_filter       - (optional) Filter events by subject string.
        subject_begins_with - (optional) Subject prefix to match.
        subject_ends_with   - (optional) Subject suffix to match.
        case_sensitive      - (optional) Case-sensitive subject matching. Default: false.
      advanced_filters     - (optional) List of fine-grained property-based filter sets. Each entry is an object whose fields are lists of { key, value/values } conditions. Default: [].
        bool_equals            - Match a boolean property exactly.
        number_greater_than    - Match a numeric property greater than a value.
        number_less_than       - Match a numeric property less than a value.
        number_in              - Match a numeric property against a set of values.
        number_not_in          - Exclude a numeric property matching a set of values.
        string_begins_with     - Match a string property by prefix.
        string_not_begins_with - Exclude a string property by prefix.
        string_ends_with       - Match a string property by suffix.
        string_not_ends_with   - Exclude a string property by suffix.
        string_contains        - Match a string property by substring.
        string_not_contains    - Exclude a string property by substring.
        string_in              - Match a string property against a set of values.
        string_not_in          - Exclude a string property matching a set of values.

    containers - ADLS Gen2 filesystem containers to create.
      container_name - Container name.
      acl            - (optional) List of ACL entries.
        scope       - "access" or "default".
        id          - Object ID of the principal.
        permissions - rwx-style permission string.
        type         - "user", "group", "mask", or "other".

    paths - Directory paths to create within containers.
      container_name - Container the path belongs to.
      path_name      - Path to create (e.g. "incoming").
      resource_type  - (optional) "directory". Default: "directory".
      acl            - (optional) List of ACL entries (same structure as containers.acl).
  EOT
  type = list(object({
    sequence_no                 = string
    snowflake_sp                = optional(string)
    sa_integration_sp           = optional(string)
    notification_integration_sp = optional(string)
    system_topic_name           = optional(string)
    sa_system_topic_principal   = optional(string)
    pep_connection = optional(object({
      pep_name          = string
      resource_id       = string
      approve           = bool
      delete_connection = optional(bool)
    }))
    queues = optional(list(object({
      name                    = string
      type                    = string # "queue" or "deadletter"
      sa_deadletter_container = optional(string)
      retry_policy = optional(object({
        max_delivery_attempts = optional(number, 30)
        event_time_to_live    = optional(number, 1440)
      }), { max_delivery_attempts = 30, event_time_to_live = 1440 })
      included_event_types = optional(list(string), ["Microsoft.Storage.BlobCreated"])
      subject_filter = optional(object({
        subject_begins_with = optional(string, "")
        subject_ends_with   = optional(string, "")
        case_sensitive      = optional(bool, false)
      }))
      advanced_filters = optional(list(object({
        bool_equals            = optional(list(object({ key = string, value = bool })), [])
        number_greater_than    = optional(list(object({ key = string, value = number })), [])
        number_less_than       = optional(list(object({ key = string, value = number })), [])
        number_in              = optional(list(object({ key = string, values = list(number) })), [])
        number_not_in          = optional(list(object({ key = string, values = list(number) })), [])
        string_begins_with     = optional(list(object({ key = string, values = list(string) })), [])
        string_not_begins_with = optional(list(object({ key = string, values = list(string) })), [])
        string_ends_with       = optional(list(object({ key = string, values = list(string) })), [])
        string_not_ends_with   = optional(list(object({ key = string, values = list(string) })), [])
        string_contains        = optional(list(object({ key = string, values = list(string) })), [])
        string_not_contains    = optional(list(object({ key = string, values = list(string) })), [])
        string_in              = optional(list(object({ key = string, values = list(string) })), [])
        string_not_in          = optional(list(object({ key = string, values = list(string) })), [])
      })), [])
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