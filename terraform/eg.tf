# ---------------------------------------------------------------------------
# RBAC: service principal → Storage Blob Data Contributor (per account)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "sp_blob_contributor" {
  for_each = local.storage_map

  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = azurerm_storage_account.sa[each.key].id
}

# ---------------------------------------------------------------------------
# RBAC: service principal → Storage Queue Data Contributor (per account)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "sp_queue_contributor" {
  for_each = local.storage_map

  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Storage Queue Data Contributor"
  scope                = azurerm_storage_account.sa[each.key].id
}

# ---------------------------------------------------------------------------
# Event Grid system topics — one per storage account
# ---------------------------------------------------------------------------
resource "azurerm_eventgrid_system_topic" "topic" {
  for_each = local.storage_map

  name                   = "${each.key}-events"
  resource_group_name    = azurerm_resource_group.arg.name
  location               = module.global.location
  source_resource_id = azurerm_storage_account.sa[each.key].id
  topic_type             = "Microsoft.Storage.StorageAccounts"

  tags = module.environment.tags
}

# ---------------------------------------------------------------------------
# Event subscriptions: BlobCreated → storage queue, one per storage account
# ---------------------------------------------------------------------------
resource "azurerm_eventgrid_event_subscription" "blob_created" {
  for_each = local.storage_map

  name  = "blob-created-to-queue"
  scope = azurerm_storage_account.sa[each.key].id

  included_event_types = ["Microsoft.Storage.BlobCreated"]

  storage_queue_endpoint {
    storage_account_id                    = azurerm_storage_account.sa[each.key].id
    queue_name                            = azurerm_storage_queue.queue[each.key].name
    queue_message_time_to_live_in_seconds = 300
  }

  depends_on = [
    azurerm_eventgrid_system_topic.topic,
    azurerm_role_assignment.sp_blob_contributor,
    azurerm_role_assignment.sp_queue_contributor,
  ]
}
