resource "azurerm_eventgrid_event_subscription" "this" {
  name  = "blob-created-to-queue"
  scope = var.storage_account_id

  included_event_types = var.included_event_types

  storage_queue_endpoint {
    storage_account_id                    = var.storage_account_id
    queue_name                            = var.queue_name
    queue_message_time_to_live_in_seconds = 300
  }

  dynamic "storage_blob_dead_letter_destination" {
    for_each = var.sa_deadletter_container != null ? [var.sa_deadletter_container] : []
    content {
      storage_account_id          = storage_blob_dead_letter_destination.value.sa_id
      storage_blob_container_name = storage_blob_dead_letter_destination.value.container_name
    }
  }

  dynamic "subject_filter" {
    for_each = var.subject_filter != null ? [var.subject_filter] : []
    content {
      subject_begins_with = subject_filter.value.subject_begins_with
      subject_ends_with   = subject_filter.value.subject_ends_with
      case_sensitive      = subject_filter.value.case_sensitive
    }
  }

  dynamic "advanced_filter" {
    for_each = var.advanced_filters
    content {
      dynamic "bool_equals" {
        for_each = advanced_filter.value.bool_equals
        content {
          key   = bool_equals.value.key
          value = bool_equals.value.value
        }
      }
      dynamic "number_greater_than" {
        for_each = advanced_filter.value.number_greater_than
        content {
          key   = number_greater_than.value.key
          value = number_greater_than.value.value
        }
      }
      dynamic "number_less_than" {
        for_each = advanced_filter.value.number_less_than
        content {
          key   = number_less_than.value.key
          value = number_less_than.value.value
        }
      }
      dynamic "number_in" {
        for_each = advanced_filter.value.number_in
        content {
          key    = number_in.value.key
          values = number_in.value.values
        }
      }
      dynamic "number_not_in" {
        for_each = advanced_filter.value.number_not_in
        content {
          key    = number_not_in.value.key
          values = number_not_in.value.values
        }
      }
      dynamic "string_begins_with" {
        for_each = advanced_filter.value.string_begins_with
        content {
          key    = string_begins_with.value.key
          values = string_begins_with.value.values
        }
      }
      dynamic "string_not_begins_with" {
        for_each = advanced_filter.value.string_not_begins_with
        content {
          key    = string_not_begins_with.value.key
          values = string_not_begins_with.value.values
        }
      }
      dynamic "string_ends_with" {
        for_each = advanced_filter.value.string_ends_with
        content {
          key    = string_ends_with.value.key
          values = string_ends_with.value.values
        }
      }
      dynamic "string_not_ends_with" {
        for_each = advanced_filter.value.string_not_ends_with
        content {
          key    = string_not_ends_with.value.key
          values = string_not_ends_with.value.values
        }
      }
      dynamic "string_contains" {
        for_each = advanced_filter.value.string_contains
        content {
          key    = string_contains.value.key
          values = string_contains.value.values
        }
      }
      dynamic "string_not_contains" {
        for_each = advanced_filter.value.string_not_contains
        content {
          key    = string_not_contains.value.key
          values = string_not_contains.value.values
        }
      }
      dynamic "string_in" {
        for_each = advanced_filter.value.string_in
        content {
          key    = string_in.value.key
          values = string_in.value.values
        }
      }
      dynamic "string_not_in" {
        for_each = advanced_filter.value.string_not_in
        content {
          key    = string_not_in.value.key
          values = string_not_in.value.values
        }
      }
    }
  }
}
