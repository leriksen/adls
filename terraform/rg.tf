resource "azurerm_resource_group" "arg" {
  location = module.global.location
  name     = "${module.global.project}arg"
  tags     = module.environment.tags
}
