resource "azurerm_resource_group" "arg" {
  location = module.global.location
  name     = "arg"
  tags     = module.environment.tags
}

resource "azurerm_resource_group" "prg" {
  location = module.global.location
  name     = "prg"
  tags     = module.environment.tags
}

resource "azurerm_resource_group" "nrg" {
  location = module.global.location
  name     = "nrg"
  tags     = module.environment.tags
}
