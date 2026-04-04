# ---------------------------------------------------------------------------
# Storage accounts
# ---------------------------------------------------------------------------
module "sa" {
  source   = "../modules/storage_account"
  for_each = local.storage_map

  resource_group_name = azurerm_resource_group.arg.name
  sequence_no         = each.key
  location            = module.global.location
  key_vault_id = azurerm_key_vault.kv.id
  tags         = module.environment.tags

  depends_on = [azurerm_role_assignment.kv_crypto_officer]
}

# ---------------------------------------------------------------------------
# ADLS Gen2 filesystems and paths
# ---------------------------------------------------------------------------
module "adls_filesystem" {
  source   = "../modules/adls_filesystem"
  for_each = local.storage_map

  storage_account_id = module.sa[each.key].id
  containers         = each.value.containers
  paths              = each.value.paths

  depends_on = [
    azurerm_role_assignment.me_blob_owner,
    time_sleep.rbac_wait,
  ]
}

# ---------------------------------------------------------------------------
# Storage queues
# ---------------------------------------------------------------------------
module "sa_queue" {
  source   = "../modules/sa_queue"
  for_each = { for k, v in local.storage_map : k => v if length(v.queues) > 0 }

  storage_account_id = module.sa[each.key].id
  queues             = each.value.queues
}

# ---------------------------------------------------------------------------
# RBAC: current user → Storage Queue Data Reader
#       (for queues of type "dlq" only)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "me_dlq_reader" {
  for_each = { for k, v in local.queue_map : k => v if v.queue_type == "dlq" }

  principal_id         = local.me
  role_definition_name = "Storage Queue Data Reader"
  scope                = "${module.sa[each.value.sa_key].id}/queueServices/default/queues/${each.value.queue_name}"
}

# ---------------------------------------------------------------------------
# RBAC: Snowflake SP → Storage Blob Data Contributor (per account where set)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "snowflake_blob_contributor" {
  for_each = local.snowflake_sp_map

  principal_id         = each.value
  role_definition_name = "Storage Blob Data Contributor"
  scope                = module.sa[each.key].id
}

# ---------------------------------------------------------------------------
# RBAC: SA integration SP → Storage Blob Data Contributor (per account where set)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "sa_integration_blob_contributor" {
  for_each = local.sa_integration_sp_map

  principal_id         = each.value
  role_definition_name = "Storage Blob Data Contributor"
  scope                = module.sa[each.key].id
}

# ---------------------------------------------------------------------------
# RBAC: notification integration SP → Storage Queue Data Contributor
#       on "queue"-typed queues only (not DLQs), per account where set
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "notification_sp_queue_contributor" {
  for_each = local.notification_sp_queue_map

  principal_id         = each.value.sp_id
  role_definition_name = "Storage Queue Data Contributor"
  scope                = "${module.sa[each.value.sa_key].id}/queueServices/default/queues/${each.value.queue_name}"
}

# ---------------------------------------------------------------------------
# RBAC: current user → Storage Blob Data Owner (required to set path ACLs)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "me_blob_owner" {
  for_each = local.storage_map

  principal_id         = local.me
  role_definition_name = "Storage Blob Data Owner"
  scope                = module.sa[each.key].id
}

# ---------------------------------------------------------------------------
# RBAC: current user → Storage Queue Data Contributor
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "me_queue_contributor" {
  for_each = local.storage_map

  principal_id         = local.me
  role_definition_name = "Storage Queue Data Contributor"
  scope                = module.sa[each.key].id
}

# ---------------------------------------------------------------------------
# RBAC: service principal → Storage Blob Data Contributor (per account)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "sp_blob_contributor" {
  for_each = local.storage_map

  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Storage Blob Data Contributor"
  scope                = module.sa[each.key].id
}

# ---------------------------------------------------------------------------
# RBAC: service principal → Storage Queue Data Contributor (per account)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "sp_queue_contributor" {
  for_each = local.storage_map

  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Storage Queue Data Contributor"
  scope                = module.sa[each.key].id
}

# ---------------------------------------------------------------------------
# RBAC propagation sleep (wait before creating filesystems and paths)
# ---------------------------------------------------------------------------
resource "time_sleep" "rbac_wait" {
  depends_on      = [azurerm_role_assignment.me_blob_owner]
  create_duration = module.global.rbac_propagation_sleep
}
