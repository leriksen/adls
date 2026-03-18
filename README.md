# ADLS Gen2 Terraform

Provisions an Azure Data Lake Storage Gen2 environment with customer-managed encryption (CMK) via Azure Key Vault.

## What this deploys

| Resource | Name | Notes |
| --- | --- | --- |
| Resource groups | `sa-arg`, `sa-prg`, `sa-nrg` | Storage, postgres (future), networking (future) |
| Storage account | `leifadls` | StorageV2, HNS enabled, shared access key disabled |
| Key Vault | `leifadslkv` | RBAC-enabled, purge-protected, 7-day soft-delete |
| CMK key | `tftest-cmk-key` | RSA-2048, 90-day auto-rotation |
| User-assigned identity | `tftest-umi` | Used by storage account to access CMK |
| Filesystems | `staging`, `forge` | ADLS Gen2 containers |
| Directories | see `modules/context/globals/outputs.tf` | ACLs applied per path |
| Queue | `testqueue` | Storage queue |

All resources are tagged via `module.environment.tags` (project, cost centre, subscription context, environment).

## Prerequisites

- Terraform `~>1.0`
- Azure CLI or a service principal with sufficient permissions
- The following dotfiles in `terraform/` (not committed):

```
.client_id_dev
.key_dev
.subscription_id
.tenant_id
.pat
```

Source credentials before running any Terraform command:

```bash
source terraform/env-dev.sh
```

## Running

All commands must be run from the `terraform/` directory.

```bash
cd terraform
source env-dev.sh

terraform init
terraform validate
terraform fmt -check -recursive

terraform plan -out=tfplan
terraform apply tfplan
```

To target a single resource:

```bash
terraform plan -target=azurerm_storage_account.sa
terraform apply -target=azurerm_key_vault.kv -auto-approve
```

## Module structure

```
terraform/              # root — run all tf commands here
modules/context/
  globals/              # shared config: location, filesystems, paths, tags, sleep duration
  environment/          # environment-specific tags (dev/sit/uat/prd)
  subscription/         # subscription context (NP = non-production)
```

## Destroying and re-deploying

### Key Vault soft-delete

The Key Vault has `purge_protection_enabled = true` and the provider is configured with:

```hcl
purge_soft_delete_on_destroy    = false
recover_soft_deleted_key_vaults = false
```

This means **if you destroy the environment, the Key Vault enters a soft-deleted state and cannot be immediately recreated with the same name**. On the next `terraform apply` the Key Vault creation will fail.

**Recovery steps after destroy:**

1. Recover the soft-deleted Key Vault in the Azure portal (Key Vaults → Manage deleted vaults) or via CLI:

   ```bash
   az keyvault recover --name leifadslkv
   ```

2. Import the recovered Key Vault into Terraform state:

   ```bash
   terraform import azurerm_key_vault.kv \
     /subscriptions/<subscription_id>/resourceGroups/sa-arg/providers/Microsoft.KeyVault/vaults/leifadslkv
   ```

3. Get the versioned key and secret URIs:

   ```bash
   az keyvault key show --vault-name leifadslkv --name tftest-cmk-key --query "key.kid" -o tsv
   az keyvault secret show --vault-name leifadslkv --name user --query "id" -o tsv
   ```

4. Import the key and secret:

   ```bash
   terraform import azurerm_key_vault_key.cmk "<key_uri_from_above>"
   terraform import azurerm_key_vault_secret.secret "<secret_uri_from_above>"
   ```

5. Re-run apply:

   ```bash
   terraform apply -auto-approve
   ```

### RBAC propagation delay

After the storage role assignments are created, there is a `time_sleep` resource that introduces a delay (configured in `modules/context/globals/outputs.tf` as `rbac_propagation_sleep`) before the Data Lake paths are created. This avoids 403 errors caused by Azure RBAC not yet propagating. If you see 403 errors on paths, re-run `terraform apply`.

## State

State is stored locally at `terraform/terraform.tfstate`. Do not commit this file — it may contain sensitive values. For team use, migrate to a remote backend (an `azurerm` backend block is the natural choice given the existing infrastructure).