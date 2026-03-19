# Event Grid system topic — automatically created by Azure when you first subscribe,
# but managing it in Terraform gives you visibility and tag control.
resource "azurerm_eventgrid_system_topic" "sa" {
  name                   = "leifadls-events"
  resource_group_name    = azurerm_resource_group.arg.name
  location               = azurerm_resource_group.arg.location
  source_resource_id = azurerm_storage_account.sa.id
  topic_type             = "Microsoft.Storage.StorageAccounts"
  tags                   = module.environment.tags
}

# Deliver BlobCreated events to the storage queue so a local consumer can poll them.
resource "azurerm_eventgrid_system_topic_event_subscription" "blob_created_queue" {
  name                = "blob-created-to-queue"
  system_topic        = azurerm_eventgrid_system_topic.sa.name
  resource_group_name = azurerm_resource_group.arg.name

  storage_queue_endpoint {
    storage_account_id                    = azurerm_storage_account.sa.id
    queue_name                            = azurerm_storage_queue.queue.name
    queue_message_time_to_live_in_seconds = 300
  }

  included_event_types = ["Microsoft.Storage.BlobCreated"]
}

# Give the Terraform service principal (ARM_CLIENT_ID) the data-plane roles it needs
# to run the Node scripts locally.
resource "azurerm_role_assignment" "sp_blob_contributor" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
}

resource "azurerm_role_assignment" "sp_queue_contributor" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_storage_queue.queue.id
  role_definition_name = "Storage Queue Data Contributor"
}