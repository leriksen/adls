# ---------------------------------------------------------------------------
# SFTP local users on argdl01
# ---------------------------------------------------------------------------
locals {
  storage_01 = one([for s in var.storage : s if s.sequence_no == "01"])

  sftp_users_resolved = [
    for u in local.storage_01.sftp_users : {
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
}

module "sftp_local_users" {
  source = "../../terraform-azurerm-sftp-local-users"

  storage_account_id = module.sa["01"].id
  sftp_users         = local.sftp_users_resolved
}
