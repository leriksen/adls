# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Initialize
terraform init

# Validate and format
terraform validate
terraform fmt -recursive          # format in place
terraform fmt -check -recursive   # check only (no changes)

# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan

# Target a single resource or module
terraform plan -target=azurerm_storage_account.sa
terraform apply -target=module.global -auto-approve

# Workspaces
export TF_WORKSPACE=name
# or: terraform workspace select <name>

# External linting/security (if installed)
tflint .
tfsec .
```

## Environment setup

Credentials live in dotfiles at `terraform/` (not committed). Source the env script before running Terraform:

```bash
source terraform/env-dev.sh   # exports ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, TF_VAR_env
source terraform/no-env.sh    # clear credentials
```

Required dotfiles: `.client_id_dev`, `.key_dev`, `.subscription_id`, `.tenant_id`, `.pat`

## Architecture

This repo is a Terraform environment overlay that provisions Azure Data Lake Storage (ADLS Gen2) infrastructure with customer-managed encryption.

**Module structure:**

```
terraform/          ← root orchestrator (working directory for all tf commands)
modules/context/
  globals/          ← shared outputs (location = australiasoutheast)
  environment/      ← environment-specific context (dev/sit/uat/prd)
  subscription/     ← subscription context (dev → "NP" non-prod)
```

Root references modules via relative paths (`../modules/context/*`).

**Key resources:**

| File | Resources |
|------|-----------|
| `rg.tf` | 3 resource groups (storage, postgres, networking) |
| `sa.tf` | StorageV2 with HNS (ADLS Gen2), CMK via inline `customer_managed_key` block, shared access key disabled |
| `akv.tf` | Key Vault (RBAC-enabled, purge-protected), RSA-2048 CMK with 90-day auto-rotate |
| `umi.tf` | User-assigned identity + RBAC role assignments (Crypto Officer, Blob/Queue Data Contributor) |
| `data.tf` | Data sources for subscription and client config |
| `locals.tf` | `local.me` (current user object ID), filesystem/path mapping |

**CMK approach:** Uses inline `customer_managed_key` block on `azurerm_storage_account` with the user-assigned identity. The older separate `azurerm_storage_account_customer_managed_key` resource is left commented in the code.

## Key conventions

- **Hard-coded names:** Storage account `leifadls`, Key Vault `leifadslkv`, UMI `tftest-umi` — search before renaming.
- **`local.me`:** Hard-coded user object ID used in RBAC assignments and path ACLs. One path ACL still has placeholder `"XXXX"`.
- **State:** Local backend (`terraform.tfstate`) — avoid committing secrets into state; migrate to remote backend for team use.
- **Key Vault:** `rbac_authorization_enabled = true` and explicit purge/soft-delete settings — be cautious when modifying.
- **Provider:** azurerm `~>4.0`, Terraform `~>1.0` (see `.terraform.lock.hcl` for pinned versions).
- **Environment variable:** `TF_VAR_env` drives environment selection; valid values: `dev`, `sit`, `uat`, `prd`.
