# resource "azurerm_virtual_network" "vnet" {
#   name                = "pg-vnet"
#   address_space       = ["10.0.0.0/16"]
#   location            = azurerm_resource_group.nrg.location
#   resource_group_name = azurerm_resource_group.nrg.name
# }
#
# resource "azurerm_subnet" "snet" {
#   name                 = "pg-subnet"
#   resource_group_name  = azurerm_resource_group.nrg.name
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   address_prefixes     = ["10.0.1.0/24"]
# }
