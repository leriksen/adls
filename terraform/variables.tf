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
      name  = string
      paths = list(string)
    }))
  }))
  default = [
    {
      name  = "leifadlsraw"
      queue = "raw-events"
      containers = [
        {
          name  = "landing"
          paths = ["incoming", "processed", "failed", "quarantine"]
        },
        {
          name  = "reference"
          paths = ["static", "lookup", "config"]
        },
        {
          name  = "staging"
          paths = ["temp", "validate"]
        },
      ]
    },
    {
      name  = "leifadlscurated"
      queue = "curated-events"
      containers = [
        {
          name  = "silver"
          paths = ["financial", "operational", "customer"]
        },
        {
          name  = "gold"
          paths = ["reporting", "analytics", "metrics", "kpi"]
        },
      ]
    },
    {
      name  = "leifadlsarchive"
      queue = "archive-events"
      containers = [
        {
          name  = "cold"
          paths = ["2023", "2024", "2025"]
        },
        {
          name  = "compliance"
          paths = ["audit", "legal", "regulatory"]
        },
        {
          name  = "backup"
          paths = ["daily", "weekly", "monthly", "yearly", "restore"]
        },
      ]
    },
    {
      name  = "leifadlssandbox"
      queue = "sandbox-events"
      containers = [
        {
          name  = "explore"
          paths = ["experiments", "prototypes", "scratch", "datasets"]
        },
        {
          name  = "share"
          paths = ["inbound", "outbound"]
        },
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