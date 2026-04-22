# ---------------------------------------------------------------------------
# RBAC: service principal → Key Vault Secrets Officer
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "kv_sec_officer" {
  principal_id         = data.azurerm_client_config.current.object_id
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
