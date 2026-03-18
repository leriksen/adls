resource "azurerm_storage_account" "sa" {
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  is_hns_enabled                  = true
  location                        = azurerm_resource_group.arg.location
  name                            = "leifadls"
  resource_group_name             = azurerm_resource_group.arg.name
  shared_access_key_enabled       = false
  queue_encryption_key_type       = "Account"
  sftp_enabled                    = false # has a cost associated with it, enable as needed
  allow_nested_items_to_be_public = false
  tags                            = module.environment.tags
  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.umi.id,
    ]
  }
  customer_managed_key {
    user_assigned_identity_id = azurerm_user_assigned_identity.umi.id
    key_vault_key_id          = azurerm_key_vault_key.cmk.id
  }
}

resource "azurerm_storage_queue" "queue" {
  storage_account_id = azurerm_storage_account.sa.id
  name               = "testqueue"
}

resource "azurerm_role_assignment" "me_queue_contributor" {
  principal_id         = local.me
  scope                = azurerm_storage_queue.queue.id
  role_definition_name = "Storage Queue Data Contributor"
}

resource "azurerm_storage_data_lake_gen2_filesystem" "fs" {
  for_each           = module.global.adls_filesystems
  name               = each.key
  storage_account_id = azurerm_storage_account.sa.id
}

resource "azurerm_role_assignment" "me_storage_contributor" {
  for_each             = module.global.adls_filesystems
  principal_id         = local.me
  scope                = format("%s/%s/%s", azurerm_storage_data_lake_gen2_filesystem.fs[each.key].storage_account_id, "blobServices/default/containers", each.key)
  role_definition_name = "Storage Blob Data Contributor"
}

resource "time_sleep" "rbac_propagation" {
  create_duration = module.global.rbac_propagation_sleep
  depends_on = [
    azurerm_role_assignment.me_storage_contributor,
    azurerm_role_assignment.me_queue_contributor,
  ]
}

resource "azurerm_storage_data_lake_gen2_path" "path" {
  for_each           = local.fs_path
  filesystem_name    = split(":", each.key)[0]
  path               = split(":", each.key)[1]
  resource           = "directory"
  storage_account_id = azurerm_storage_account.sa.id
  depends_on         = [time_sleep.rbac_propagation]
  dynamic "ace" {
    for_each = local.fs_path_acls[each.key]
    content {
      type        = ace.value.type
      id          = ace.value.id
      scope       = ace.value.scope
      permissions = ace.value.permissions
    }
  }
}