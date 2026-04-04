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

variable "advanced_filter" {
  type = object({
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
  })
  default = null
}
