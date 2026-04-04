# ---------------------------------------------------------------------------
# Storage accounts
# ---------------------------------------------------------------------------
module "sa" {
  source   = "../modules/storage_account"
  for_each = local.storage_map

  resource_group_name = azurerm_resource_group.arg.name
  sequence_no         = each.key
  location            = module.global.location
  key_vault_id        = azurerm_key_vault.kv.id
  tags                = module.environment.tags

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
  for_each = local.queue_map

  storage_account_id = module.sa[each.value.sa_key].id
  queue_name         = each.value.queue_name
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
# Private endpoint connection — approve
# ---------------------------------------------------------------------------
module "pep_approve" {
  source   = "../modules/pep-approve"
  for_each = local.pep_approve_map

  pep_name    = each.value.pep_connection.pep_name
  resource_id = each.value.pep_connection.resource_id
}

# ---------------------------------------------------------------------------
# Private endpoint connection — deny
# ---------------------------------------------------------------------------
module "pep_deny" {
  source   = "../modules/pep-deny"
  for_each = local.pep_deny_map

  pep_name       = each.value.pep_connection.pep_name
  resource_id    = each.value.pep_connection.resource_id
  rejection_only = each.value.pep_connection.delete_connection != null ? each.value.pep_connection.delete_connection : true
}

# ---------------------------------------------------------------------------
# RBAC propagation sleep (wait before creating filesystems and paths)
# ---------------------------------------------------------------------------
resource "time_sleep" "rbac_wait" {
  depends_on      = [azurerm_role_assignment.me_blob_owner]
  create_duration = module.global.rbac_propagation_sleep
}
