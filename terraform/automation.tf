resource "azurerm_automation_account" "aa" {
  name                = "${azurerm_resource_group.arg.name}aa"
  location            = module.global.location
  resource_group_name = azurerm_resource_group.arg.name
  sku_name            = "Basic"
  tags                = module.environment.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "aa_sa_contributor" {
  for_each = { for k, v in local.storage_map : k => v if try(v.sftp_enabled, false) }

  principal_id         = azurerm_automation_account.aa.identity[0].principal_id
  role_definition_name = "Storage Account Contributor"
  scope                = module.sa[each.key].id
}

resource "azurerm_automation_runbook" "sftp_toggle" {
  for_each = { for k, v in local.storage_map : k => v if try(v.sftp_enabled, false) }

  name                    = "${azurerm_resource_group.arg.name}dl${each.key}_sftp_toggle"
  location                = module.global.location
  resource_group_name     = azurerm_resource_group.arg.name
  automation_account_name = azurerm_automation_account.aa.name
  log_verbose             = false
  log_progress            = false
  runbook_type            = "PowerShell"
  tags                    = module.environment.tags

  content = file("${path.module}/runbooks/sftp_toggle.ps1")
}