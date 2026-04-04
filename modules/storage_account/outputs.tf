output "id" {
  value = azurerm_storage_account.this.id
}

output "umi_id" {
  value = azurerm_user_assigned_identity.this.id
}

output "umi_principal_id" {
  value = azurerm_user_assigned_identity.this.principal_id
}

output "system_topic_name" {
  value = azurerm_eventgrid_system_topic.this.name
}

output "system_topic_principal_id" {
  value = azurerm_eventgrid_system_topic.this.identity[0].principal_id
}
