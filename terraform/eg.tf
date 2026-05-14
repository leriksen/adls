# ---------------------------------------------------------------------------
# Enable SystemAssigned managed identity on each discovered system topic.
# Runs for every topic that exists (sa_with_event_subscriptions), regardless
# of whether the identity is already on. Idempotent PATCH.
# ---------------------------------------------------------------------------
resource "azapi_update_resource" "system_topic_identity" {
  for_each = local.sa_with_event_subscriptions

  type        = "Microsoft.EventGrid/systemTopics@2022-06-15"
  resource_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.arg.name}/providers/Microsoft.EventGrid/systemTopics/${local.system_topics_by_source[local.sa_resource_id[each.key]]}"

  body = {
    identity = {
      type = "SystemAssigned"
    }
  }
}

# ---------------------------------------------------------------------------
# Event subscriptions: BlobCreated → storage queue, one per storage account.
# Only created once the system topic's managed identity is confirmed active
# (sa_with_managed_identity). Skipped if identity is not yet enabled.
# ---------------------------------------------------------------------------
module "eg_subscription" {
  source   = "../modules/eg_subscription"
  for_each = local.sa_with_managed_identity

  storage_account_id   = module.sa[each.key].id
  queue_name           = local.sa_event_queue[each.key].name
  system_topic         = local.system_topic_info[each.key]
  retry_policy         = local.sa_event_queue[each.key].retry_policy
  included_event_types = local.sa_event_queue[each.key].included_event_types
  subject_filter       = local.sa_event_queue[each.key].subject_filter
  advanced_filters     = local.sa_event_queue[each.key].advanced_filters
  sa_deadletter_container = local.sa_event_queue[each.key].sa_deadletter_container != null ? {
    sa_id          = module.sa[each.key].id
    container_name = local.sa_event_queue[each.key].sa_deadletter_container
  } : null

  depends_on = [
    module.sa,
    azurerm_role_assignment.eg_queue_sender,
    azapi_update_resource.system_topic_identity,
  ]
}

# ---------------------------------------------------------------------------
# RBAC: event grid system topic identity → Storage Queue Data Message Sender
#       (for queues of type "queue" only)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "eg_queue_sender" {
  for_each = local.event_queues

  principal_id         = local.system_topic_info[each.value.sa_key].principal_id
  role_definition_name = "Storage Queue Data Message Sender"
  scope                = "${module.sa[each.value.sa_key].id}/queueServices/default/queues/${each.value.queue_name}"
}

# ---------------------------------------------------------------------------
# RBAC: Event Grid system topic managed identity → Storage Blob Data Contributor
#       scoped to the "deadletter" container, for SAs that have one
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "eg_deadletter_blob_contributor" {
  for_each = local.eg_deadletter_queues

  principal_id         = local.system_topic_info[each.key].principal_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = "${module.sa[each.key].id}/blobServices/default/containers/deadletter"
}
