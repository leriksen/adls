resource "azurerm_key_vault" "kv" {
  location                   = azurerm_resource_group.arg.location
  name                       = "leifadslkv"
  resource_group_name        = azurerm_resource_group.arg.name
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled   = true
  rbac_authorization_enabled = true
  # Note: Enabling purge_protection is irreversible and requires privileged permissions

  soft_delete_retention_days = 7
  tags                       = module.environment.tags
}

resource "azurerm_role_assignment" "kv_sec_officer" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
}

resource "azurerm_role_assignment" "me_sec_officer" {
  principal_id         = local.me
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
}

resource "azurerm_key_vault_secret" "secret" {
  depends_on = [
    azurerm_role_assignment.kv_sec_officer
  ]
  key_vault_id = azurerm_key_vault.kv.id
  name         = "user"
  value        = azurerm_user_assigned_identity.umi.id
  tags         = module.environment.tags
}

resource "azurerm_role_assignment" "kv_crypto_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "me_crypto_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = local.me
}

resource "azurerm_key_vault_key" "cmk" {
  name            = "tftest-cmk-key"
  key_vault_id    = azurerm_key_vault.kv.id
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

  tags       = module.environment.tags
  depends_on = [azurerm_role_assignment.kv_crypto_officer]
}

resource "azurerm_role_assignment" "cmk_reader" {
  principal_id         = azurerm_user_assigned_identity.umi.principal_id
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Crypto User"
}
