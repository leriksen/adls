resource "azurerm_resource_group" "arg" {
  location = module.global.location
  name     = "${module.global.project}arg"
  tags     = module.environment.tags
}

resource "azurerm_role_assignment" "portal_test_user_rg_reader" {
  count = var.portal_test_user_object_id != null ? 1 : 0

  principal_id         = var.portal_test_user_object_id
  role_definition_name = "Reader"
  scope                = azurerm_resource_group.arg.id
}
