resource "azurerm_resource_group" "arg" {
  location = module.global.location
  name     = "sa-arg"
  tags     = module.environment.tags
}

resource "azurerm_resource_group" "prg" {
  location = module.global.location
  name     = "sa-prg"
  tags     = module.environment.tags
}

resource "azurerm_resource_group" "nrg" {
  location = module.global.location
  name     = "sa-nrg"
  tags     = module.environment.tags
}
