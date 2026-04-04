resource "azurerm_eventgrid_event_subscription" "this" {
  name  = "blob-created-to-queue"
  scope = var.storage_account_id

  included_event_types = ["Microsoft.Storage.BlobCreated"]

  storage_queue_endpoint {
    storage_account_id                    = var.storage_account_id
    queue_name                            = var.queue_name
    queue_message_time_to_live_in_seconds = 300
  }
}
