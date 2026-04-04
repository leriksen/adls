# ---------------------------------------------------------------------------
# Key Vault — shared across all storage accounts
# ---------------------------------------------------------------------------
resource "azurerm_key_vault" "kv" {
  name                       = "leiftdpakv"
  location                   = azurerm_resource_group.arg.location
  resource_group_name        = azurerm_resource_group.arg.name
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled   = true
  rbac_authorization_enabled = true
  # Note: Enabling purge_protection is irreversible and requires privileged permissions

  soft_delete_retention_days = 7
  tags                       = module.environment.tags
}

# ---------------------------------------------------------------------------
# Key Vault secrets — one per storage account, storing its UMI resource ID
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "umi" {
  for_each = module.sa

  depends_on = [azurerm_role_assignment.kv_sec_officer]

  key_vault_id = azurerm_key_vault.kv.id
  name         = "umi-${each.key}"
  value        = each.value.umi_id
  tags         = module.environment.tags
}
