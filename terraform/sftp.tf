# ---------------------------------------------------------------------------
# SSH key pairs for SFTP local users (ECDSA P-256)
# ---------------------------------------------------------------------------
resource "tls_private_key" "sftp_push" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "sftp_pull" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ---------------------------------------------------------------------------
# SFTP local users on argdl01
# ---------------------------------------------------------------------------
module "sftp_local_users" {
  source = "../../terraform-azurerm-sftp-local-users"

  storage_account_id = module.sa["01"].id

  sftp_users = [
    {
      sequence_number = 0
      home_directory  = "landing/dev01/inbound"
      ssh_key_enabled = true
      permission_scopes = [
        {
          target_container = "landing"
          service          = "blob"
          permissions      = ["Create", "Write", "Read", "List", "Delete"]
        }
      ]
      ssh_authorized_keys = [
        {
          key         = trimspace(tls_private_key.sftp_push.public_key_openssh)
          description = "sftp-push-user"
        }
      ]
    },
    {
      sequence_number = 1
      home_directory  = "landing/dev01/inbound"
      ssh_key_enabled = true
      permission_scopes = [
        {
          target_container = "landing"
          service          = "blob"
          permissions      = ["Read", "List"]
        }
      ]
      ssh_authorized_keys = [
        {
          key         = trimspace(tls_private_key.sftp_pull.public_key_openssh)
          description = "sftp-pull-user"
        }
      ]
    }
  ]
}

# ---------------------------------------------------------------------------
# Private key outputs — sensitive, retrieve with: terraform output -json
# ---------------------------------------------------------------------------
output "sftp_push_private_key" {
  value     = tls_private_key.sftp_push.private_key_openssh
  sensitive = true
}

output "sftp_pull_private_key" {
  value     = tls_private_key.sftp_pull.private_key_openssh
  sensitive = true
}
