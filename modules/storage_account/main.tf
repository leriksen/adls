resource "azurerm_user_assigned_identity" "this" {
  name                = "tftest-umi-${var.sequence_no}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_key_vault_key" "cmk" {
  name            = "tftest-cmk-key-${var.sequence_no}"
  key_vault_id    = var.key_vault_id
  key_type        = "RSA"
  key_size        = 2048
  key_opts        = ["encrypt", "decrypt", "sign", "verify", "wrapKey", "unwrapKey"]
  expiration_date = "2027-03-12T03:07:58Z"

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "cmk_reader" {
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Crypto User"
}

resource "azurerm_storage_account" "this" {
  name                            = "${var.resource_group_name}dl${var.sequence_no}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  is_hns_enabled                  = true
  sftp_enabled                    = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }

  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.cmk.id
    user_assigned_identity_id = azurerm_user_assigned_identity.this.id
  }

  tags = var.tags
}

resource "azurerm_eventgrid_system_topic" "this" {
  name                = "${var.sequence_no}-events"
  resource_group_name = var.resource_group_name
  location            = var.location
  source_resource_id  = azurerm_storage_account.this.id
  topic_type          = "Microsoft.Storage.StorageAccounts"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
