# ---------------------------------------------------------------------------
# Storage accounts
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "sa" {
  for_each = local.storage_map

  name                            = each.key
  resource_group_name             = azurerm_resource_group.arg.name
  location                        = module.global.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  is_hns_enabled                  = true
  sftp_enabled                    = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.umi.id]
  }

  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.cmk.id
    user_assigned_identity_id = azurerm_user_assigned_identity.umi.id
  }

  tags = module.environment.tags
}

# ---------------------------------------------------------------------------
# ADLS Gen2 containers (filesystems) and paths via legacy module
# ---------------------------------------------------------------------------
module "adls_container_and_paths" {
  source  = "localterraform.com/customers/adls_container/azurerm"
  version = "10.0.0"

  for_each = local.adls_module_map

  storage_account_id   = azurerm_storage_account.sa[each.value.sa_name].id
  data_lake_containers = each.value.containers
  data_lake_paths      = each.value.paths

  depends_on = [
    azurerm_role_assignment.me_blob_owner,
    time_sleep.rbac_wait,
  ]
}

# ---------------------------------------------------------------------------
# Storage queues
# ---------------------------------------------------------------------------
resource "azurerm_storage_queue" "queue" {
  for_each = local.storage_map

  name               = each.value.queue
  storage_account_id = azurerm_storage_account.sa[each.key].id
}

# ---------------------------------------------------------------------------
# RBAC: current user → Storage Blob Data Owner (required to set path ACLs)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "me_blob_owner" {
  for_each = local.storage_map

  principal_id         = local.me
  role_definition_name = "Storage Blob Data Owner"
  scope                = azurerm_storage_account.sa[each.key].id
}

# ---------------------------------------------------------------------------
# RBAC: current user → Storage Queue Data Contributor
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "me_queue_contributor" {
  for_each = local.storage_map

  principal_id         = local.me
  role_definition_name = "Storage Queue Data Contributor"
  scope                = azurerm_storage_account.sa[each.key].id
}

# ---------------------------------------------------------------------------
# RBAC propagation sleep (wait before creating filesystems and paths)
# ---------------------------------------------------------------------------
resource "time_sleep" "rbac_wait" {
  depends_on      = [azurerm_role_assignment.me_blob_owner]
  create_duration = module.global.rbac_propagation_sleep
}
