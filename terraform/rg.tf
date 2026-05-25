resource "azurerm_resource_group" "arg" {
  location = module.global.location
  name     = "${module.global.project}arg"
  tags     = module.environment.tags
}

resource "azurerm_role_assignment" "adls_writer_rg_reader" {
  count = var.adls_writer_object_id != null ? 1 : 0

  principal_id         = var.adls_writer_object_id
  role_definition_name = "Reader"
  scope                = azurerm_resource_group.arg.id
}

resource "azurerm_role_assignment" "adls_reader_rg_reader" {
  count = var.adls_reader_object_id != null ? 1 : 0

  principal_id         = var.adls_reader_object_id
  role_definition_name = "Reader"
  scope                = azurerm_resource_group.arg.id
}
