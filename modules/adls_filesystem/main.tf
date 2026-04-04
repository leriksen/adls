resource "azurerm_storage_data_lake_gen2_filesystem" "this" {
  for_each = { for c in var.containers : c.container_name => c }

  name               = each.key
  storage_account_id = var.storage_account_id

  dynamic "ace" {
    for_each = each.value.acl
    content {
      scope       = ace.value.scope
      id          = ace.value.id
      permissions = ace.value.permissions
      type        = ace.value.type
    }
  }
}

resource "azurerm_storage_data_lake_gen2_path" "this" {
  for_each = { for p in var.paths : "${p.container_name}::${p.path_name}" => p }

  path               = each.value.path_name
  filesystem_name    = each.value.container_name
  storage_account_id = var.storage_account_id
  resource           = each.value.resource_type

  dynamic "ace" {
    for_each = each.value.acl
    content {
      scope       = ace.value.scope
      id          = ace.value.id
      permissions = ace.value.permissions
      type        = ace.value.type
    }
  }

  depends_on = [azurerm_storage_data_lake_gen2_filesystem.this]
}
