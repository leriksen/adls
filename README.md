# ADLS Gen2 Terraform

Provisions two Azure Data Lake Storage Gen2 storage accounts with customer-managed encryption (CMK) via Azure Key Vault, Event Grid subscriptions, and supporting infrastructure.

## What this deploys

| Resource | Name(s) | Notes |
|----------|---------|-------|
| Resource groups | `arg`, `prg`, `nrg` | Storage, postgres (future), networking (future) |
| Storage accounts | `argdl01`, `argdl02` | StorageV2, HNS enabled, shared access key disabled |
| Key Vault | `leiftdpakv` | RBAC-enabled, purge-protected, 7-day soft-delete |
| CMK keys | `tftest-cmk-key-01`, `tftest-cmk-key-02` | RSA-2048, 90-day auto-rotation, one per SA |
| User-assigned identities | `tftest-umi-01`, `tftest-umi-02` | One per SA, used to access CMK |
| Filesystems (argdl01) | `landing`, `reference`, `staging`, `deadletter` | ADLS Gen2 containers |
| Filesystems (argdl02) | `silver`, `gold`, `deadletter` | ADLS Gen2 containers |
| Queues (argdl01) | `raw-events`, `deadletter` | EG delivery + dead-letter inspection |
| Queues (argdl02) | `curated-events`, `deadletter` | EG delivery + dead-letter inspection |
| Event Grid subscriptions | `01-events`, `02-events` | BlobCreated → storage queue, per SA |

All resources are tagged via `module.environment.tags` (project, cost centre, subscription context, environment).

### Event Grid filters

| SA | Queue | Subject filter | Extension filter |
|----|-------|---------------|-----------------|
| argdl01 | `raw-events` | `landing` container only | `.parquet`, `.csv`, `.json` |
| argdl02 | `curated-events` | `silver` container only | `.parquet` |

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
terraform plan -target=module.sa
terraform apply -target=azurerm_key_vault.kv -auto-approve
```

## Module structure

```
terraform/                  # root — run all tf commands here
modules/
  storage_account/          # StorageV2 + HNS + CMK + UMI
  adls_filesystem/          # Gen2 containers and directory paths
  sa_queue/                 # Storage queues
  eg_subscription/          # Event Grid system topic subscription
  pep-approve/              # Private endpoint approval
  pep-deny/                 # Private endpoint denial
  context/
    globals/                # Shared config: location, tags
    environment/            # Environment-specific tags (dev/sit/uat/prd)
    subscription/           # Subscription context (NP = non-production)
```

## Event Grid driver scripts

The `eventgrid/` directory contains three Node.js scripts for testing the Event Grid pipeline end-to-end. Auth uses the same `ARM_*` env vars as Terraform — source `terraform/env-dev.sh` first.

### producer.js

Uploads `.parquet` files to the `landing` container on `argdl01` and the `silver` container on `argdl02` at ~15/min with jitter. These are the only containers that pass the Event Grid subject filters.

```bash
cd eventgrid
node producer.js
```

### consumer.js

Polls `raw-events` (argdl01) and `curated-events` (argdl02) for `BlobCreated` events, waits ~2s, then deletes the blob. Runs at ~12/min average.

```bash
cd eventgrid
node consumer.js
```

### cleanup.js

Recursively deletes all **files** (not directories) from all filesystems across both storage accounts. Safe to run at any point — skips missing accounts or filesystems. Run before `terraform destroy` to avoid 409 errors.

```bash
cd eventgrid
node cleanup.js
```

## Destroying and re-deploying

### Pre-destroy cleanup

Before running `terraform destroy`, delete all blob content to avoid 409 errors:

```bash
cd eventgrid && node cleanup.js
```

### Key Vault soft-delete

The Key Vault has `purge_protection_enabled = true`. If you destroy the environment, the Key Vault enters a soft-deleted state and cannot be immediately recreated with the same name. On the next `terraform apply` the Key Vault creation will fail.

**Recovery steps after destroy:**

1. Recover the soft-deleted Key Vault:

   ```bash
   az keyvault recover --name leiftdpakv
   ```

2. Import the recovered Key Vault into Terraform state:

   ```bash
   terraform import azurerm_key_vault.kv \
     /subscriptions/<subscription_id>/resourceGroups/arg/providers/Microsoft.KeyVault/vaults/leiftdpakv
   ```

3. Re-run apply:

   ```bash
   terraform apply -auto-approve
   ```

### RBAC propagation delay

After storage role assignments are created, a `time_sleep` resource introduces a delay before the Data Lake paths are created. This avoids 403 errors caused by Azure RBAC not yet propagating. If you see 403 errors on paths, re-run `terraform apply`.

## State

State is stored locally at `terraform/terraform.tfstate`. Do not commit this file — it may contain sensitive values. For team use, migrate to a remote backend (an `azurerm` backend block is the natural choice given the existing infrastructure).
