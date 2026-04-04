variable "storage_account_id" {
  type = string
}

variable "queue_name" {
  type = string
}

variable "system_topic_name" {
  type = string
}

variable "included_event_types" {
  type = list(string)
}

variable "subject_filter" {
  type = object({
    subject_begins_with = optional(string, "")
    subject_ends_with   = optional(string, "")
    case_sensitive      = optional(bool, false)
  })
  default = null
}

variable "sa_deadletter_container" {
  description = "Optional dead-letter destination. If set, undeliverable events are written to this blob container."
  type = object({
    sa_id          = string
    container_name = string
  })
  default = null
}

variable "retry_policy" {
  type = object({
    max_delivery_attempts = optional(number, 30)
    event_time_to_live    = optional(number, 1440)
  })
  default = {
    max_delivery_attempts = 30
    event_time_to_live    = 1440
  }
}

variable "advanced_filters" {
  type = list(object({
    bool_equals            = optional(list(object({ key = string, value = bool   })), [])
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
  }))
  default = []
}
