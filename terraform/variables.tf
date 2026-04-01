variable "environment" {
  type    = string
  default = "dev"
}

variable "storage" {
  description = "ADLS Gen2 storage accounts to provision, each with queues, containers, and paths."
  type = list(object({
    name = string
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
      acl = list(object({
        scope       = string
        id          = string
        permissions = string
        type        = string
      }))
    }))
  }))
  default = [
    {
      name = "leifadlsraw"
      queues = [
        { name = "raw-events", type = "queue" },
        { name = "raw-dlq",    type = "dlq" },
      ]
      containers = [
        { container_name = "landing",   acl = [] },
        { container_name = "reference", acl = [] },
        { container_name = "staging",   acl = [] },
      ]
      paths = [
        { container_name = "landing", path_name = "incoming",   resource_type = "directory", acl = [] },
        { container_name = "landing", path_name = "processed",  resource_type = "directory", acl = [] },
        { container_name = "landing", path_name = "failed",     resource_type = "directory", acl = [] },
        { container_name = "landing", path_name = "quarantine", resource_type = "directory", acl = [] },

        { container_name = "reference", path_name = "static", resource_type = "directory", acl = [] },
        { container_name = "reference", path_name = "lookup", resource_type = "directory", acl = [] },
        { container_name = "reference", path_name = "config", resource_type = "directory", acl = [] },

        { container_name = "staging", path_name = "temp",     resource_type = "directory", acl = [] },
        { container_name = "staging", path_name = "validate", resource_type = "directory", acl = [] },
      ]
    },
    {
      name = "leifadlscurated"
      queues = [
        { name = "curated-events", type = "queue" },
        { name = "curated-dlq",    type = "dlq" },
      ]
      containers = [
        { container_name = "silver", acl = [] },
        { container_name = "gold",   acl = [] },
      ]
      paths = [
        { container_name = "silver", path_name = "financial",   resource_type = "directory", acl = [] },
        { container_name = "silver", path_name = "operational", resource_type = "directory", acl = [] },
        { container_name = "silver", path_name = "customer",    resource_type = "directory", acl = [] },

        { container_name = "gold", path_name = "reporting", resource_type = "directory", acl = [] },
        { container_name = "gold", path_name = "analytics", resource_type = "directory", acl = [] },
        { container_name = "gold", path_name = "metrics",   resource_type = "directory", acl = [] },
        { container_name = "gold", path_name = "kpi",       resource_type = "directory", acl = [] },
      ]
    }
  ]
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