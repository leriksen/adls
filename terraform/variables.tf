variable "environment" {
  type    = string
  default = "dev"
}

variable "storage" {
  description = "ADLS Gen2 storage accounts to provision, each with a queue, containers, and paths."
  type = list(object({
    name  = string
    queue = string
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
      name  = "leifadlsraw"
      queue = "raw-events"
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
      name  = "leifadlscurated"
      queue = "curated-events"
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
    },
    {
      name  = "leifadlsarchive"
      queue = "archive-events"
      containers = [
        { container_name = "cold",       acl = [] },
        { container_name = "compliance", acl = [] },
        { container_name = "backup",     acl = [] },
      ]
      paths = [
        { container_name = "cold", path_name = "2023", resource_type = "directory", acl = [] },
        { container_name = "cold", path_name = "2024", resource_type = "directory", acl = [] },
        { container_name = "cold", path_name = "2025", resource_type = "directory", acl = [] },

        { container_name = "compliance", path_name = "audit",      resource_type = "directory", acl = [] },
        { container_name = "compliance", path_name = "legal",      resource_type = "directory", acl = [] },
        { container_name = "compliance", path_name = "regulatory", resource_type = "directory", acl = [] },

        { container_name = "backup", path_name = "daily",   resource_type = "directory", acl = [] },
        { container_name = "backup", path_name = "weekly",  resource_type = "directory", acl = [] },
        { container_name = "backup", path_name = "monthly", resource_type = "directory", acl = [] },
        { container_name = "backup", path_name = "yearly",  resource_type = "directory", acl = [] },
        { container_name = "backup", path_name = "restore", resource_type = "directory", acl = [] },
      ]
    },
    {
      name  = "leifadlssandbox"
      queue = "sandbox-events"
      containers = [
        { container_name = "explore", acl = [] },
        { container_name = "share",   acl = [] },
      ]
      paths = [
        { container_name = "explore", path_name = "experiments", resource_type = "directory", acl = [] },
        { container_name = "explore", path_name = "prototypes",  resource_type = "directory", acl = [] },
        { container_name = "explore", path_name = "scratch",     resource_type = "directory", acl = [] },
        { container_name = "explore", path_name = "datasets",    resource_type = "directory", acl = [] },

        { container_name = "share", path_name = "inbound",  resource_type = "directory", acl = [] },
        { container_name = "share", path_name = "outbound", resource_type = "directory", acl = [] },
      ]
    },
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