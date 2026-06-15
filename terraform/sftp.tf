# ---------------------------------------------------------------------------
# SFTP local users — one module instance per storage account that defines
# sftp_users. Adding or removing users in vars is the only change needed.
# ---------------------------------------------------------------------------
locals {
  sftp_configs = {
    for s in var.storage : s.sequence_no => [
      for u in s.sftp_users : {
        sequence_number = u.sequence_number
        home_directory  = u.home_directory
        ssh_key_enabled = u.ssh_key_enabled
        permission_scopes = u.permission_scopes
        ssh_authorized_keys = [
          for k in u.ssh_authorized_keys : {
            key         = trimspace(file(k.public_key_path))
            description = k.description
          }
        ]
      }
    ]
    if length(s.sftp_users) > 0
  }
}

module "sftp_local_users" {
  for_each = local.sftp_configs
  source   = "../../terraform-azurerm-sftp-local-users"

  storage_account_id = module.sa[each.key].id
  sftp_users         = each.value
}
