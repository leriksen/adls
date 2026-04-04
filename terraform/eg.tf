# ---------------------------------------------------------------------------
# RBAC: event grid system topic identity → Storage Queue Data Message Sender
#       (for queues of type "queue" only)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "eg_queue_sender" {
  for_each = local.event_queues

  principal_id         = each.value.sa_system_topic_principal
  role_definition_name = "Storage Queue Data Message Sender"
  scope                = "${module.sa[each.value.sa_key].id}/queueServices/default/queues/${each.value.queue_name}"
}

# ---------------------------------------------------------------------------
# RBAC: Event Grid system topic managed identity → Storage Blob Data Contributor
#       scoped to the "deadletter" container, for SAs that have one
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "eg_deadletter_blob_contributor" {
  for_each = local.eg_deadletter_queues

  principal_id         = each.value.sa_system_topic_principal
  role_definition_name = "Storage Blob Data Contributor"
  scope                = "${module.sa[each.key].id}/blobServices/default/containers/deadletter"
}

# ---------------------------------------------------------------------------
# Event subscriptions: BlobCreated → storage queue, one per storage account
# ---------------------------------------------------------------------------
module "eg_subscription" {
  source   = "../modules/eg_subscription"
  for_each = local.sa_with_event_subscription

  storage_account_id = module.sa[each.key].id
  queue_name         = local.sa_event_queue[each.key]
  system_topic_name  = each.value.system_topic_name

  depends_on = [
    module.sa,
    azurerm_role_assignment.sp_blob_contributor,
    azurerm_role_assignment.sp_queue_contributor,
    azurerm_role_assignment.eg_queue_sender,
  ]
}
