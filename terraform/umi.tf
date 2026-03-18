resource "azurerm_user_assigned_identity" "umi" {
  name                = "tftest-umi"
  location            = azurerm_resource_group.arg.location
  resource_group_name = azurerm_resource_group.arg.name
  tags                = module.environment.tags
}
