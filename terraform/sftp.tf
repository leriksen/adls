module "sftp_local_users" {
  for_each = local.sftp_configs
  source   = "../../terraform-azurerm-sftp-local-users"

  storage_account_id = module.sa[each.key].id
  sftp_users         = each.value
}
