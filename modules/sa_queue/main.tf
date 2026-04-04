resource "azurerm_storage_queue" "this" {
  for_each = { for q in var.queues : q.name => q }

  name               = each.key
  storage_account_id = var.storage_account_id
}
