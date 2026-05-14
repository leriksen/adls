resource "azurerm_user_assigned_identity" "this" {
  name                = "tftest-umi-${var.sequence_no}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
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

  tags = var.tags
}
