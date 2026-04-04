# ---------------------------------------------------------------------------
# RBAC: service principal → Key Vault Secrets Officer
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "kv_sec_officer" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
}

# ---------------------------------------------------------------------------
# RBAC: current user → Key Vault Secrets Officer
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "me_sec_officer" {
  principal_id         = local.me
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
}

# ---------------------------------------------------------------------------
# RBAC: service principal → Key Vault Crypto Officer
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "kv_crypto_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---------------------------------------------------------------------------
# RBAC: current user → Key Vault Crypto Officer
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "me_crypto_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = local.me
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
# RBAC: current user → Storage Queue Data Reader
#       (for queues of type "deadletter" only)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "me_dlq_reader" {
  for_each = local.deadletter_queues

  principal_id         = local.me
  role_definition_name = "Storage Queue Data Reader"
  scope                = "${module.sa[each.value.sa_key].id}/queueServices/default/queues/${each.value.queue_name}"
}
