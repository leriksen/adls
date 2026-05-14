output "id" {
  value = azurerm_storage_account.this.id
}

output "umi_id" {
  value = azurerm_user_assigned_identity.this.id
}

output "umi_principal_id" {
  value = azurerm_user_assigned_identity.this.principal_id
}

