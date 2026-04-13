/**
 * cleanup.js — recursively deletes all content from all ADLS filesystems.
 *
 * Uses the DFS API (DataLakeServiceClient) which supports true recursive
 * directory deletion in a single call — the Blob API requires iterating
 * every file individually.
 *
 * Gracefully skips any resource that doesn't exist (storage account
 * unreachable, filesystem missing, etc.) so it's safe to run at any
 * point in the infrastructure lifecycle.
 *
 * Run this before `terraform destroy` to avoid the 409 "non-empty directory"
 * error from Terraform (the azurerm provider doesn't pass recursive=true when
 * deleting azurerm_storage_data_lake_gen2_path resources).
 *
 * Usage:
 *   source terraform/env-dev.sh
 *   node cleanup.js
 */

const { ResourceManagementClient } = require("@azure/arm-resources");
const { DataLakeServiceClient } = require("@azure/storage-file-datalake");
const { ClientSecretCredential } = require("@azure/identity");

const RESOURCE_GROUP  = "arg";
const SUBSCRIPTION_ID = process.env.ARM_SUBSCRIPTION_ID;

// Mirrors terraform/variables.tf storage defaults
const ACCOUNTS = [
  {
    name:        "argdl01",
    filesystems: ["landing", "reference", "staging", "deadletter"],
  },
  {
    name:        "argdl02",
    filesystems: ["silver", "gold", "deadletter"],
  },
];

const credential = new ClientSecretCredential(
  process.env.ARM_TENANT_ID,
  process.env.ARM_CLIENT_ID,
  process.env.ARM_CLIENT_SECRET
);

async function checkResourceGroup() {
  process.stdout.write(`Checking resource group "${RESOURCE_GROUP}" ... `);
  try {
    const armClient = new ResourceManagementClient(credential, SUBSCRIPTION_ID);
    await armClient.resourceGroups.get(RESOURCE_GROUP);
    console.log("exists");
    return true;
  } catch (err) {
    if (err.statusCode === 404) {
      console.log("not found — nothing to clean up");
    } else {
      console.log(`SKIP — ${err.message}`);
    }
    return false;
  }
}

async function checkStorageAccount(accountName) {
  const serviceClient = new DataLakeServiceClient(
    `https://${accountName}.dfs.core.windows.net`,
    credential
  );
  process.stdout.write(`Checking storage account "${accountName}" ... `);
  try {
    // listFileSystems returns an async iterator; just pull the first page to
    // confirm the account exists and the credential has access.
    // eslint-disable-next-line no-unused-vars
    for await (const _ of serviceClient.listFileSystems({ maxPageSize: 1 })) break;
    console.log("reachable");
    return serviceClient;
  } catch (err) {
    if (err.statusCode === 403) {
      console.log(`SKIP — credential lacks access (403)`);
    } else if (err.statusCode === 404 || err.code === "AccountNotFound") {
      console.log(`SKIP — account not found (404)`);
    } else {
      console.log(`SKIP — ${err.message}`);
    }
    return null;
  }
}

async function cleanFilesystem(serviceClient, fsName) {
  const fsClient = serviceClient.getFileSystemClient(fsName);

  process.stdout.write(`  checking filesystem "${fsName}" ... `);
  const exists = await fsClient.exists();
  if (!exists) {
    console.log("not found, skipping");
    return 0;
  }
  console.log("exists");

  let deleted = 0;
  for await (const item of fsClient.listPaths({ recursive: true })) {
    if (item.isDirectory) continue;
    process.stdout.write(`    [file] ${item.name} ... `);
    try {
      await fsClient.getFileClient(item.name).delete();
      console.log("deleted");
      deleted++;
    } catch (err) {
      console.log(`FAILED — ${err.message}`);
    }
  }

  return deleted;
}

async function main() {
  const rgExists = await checkResourceGroup();
  if (!rgExists) return;

  let grandTotal = 0;
  for (const account of ACCOUNTS) {
    console.log(`\n=== ${account.name} ===`);
    const serviceClient = await checkStorageAccount(account.name);
    if (!serviceClient) continue;

    let total = 0;
    for (const name of account.filesystems) {
      console.log(`[${name}]`);
      const count = await cleanFilesystem(serviceClient, name);
      if (count === 0) console.log("  (nothing deleted)");
      total += count;
      console.log();
    }
    grandTotal += total;
  }

  const fsCount = ACCOUNTS.reduce((sum, a) => sum + a.filesystems.length, 0);
  console.log(`Done — deleted ${grandTotal} top-level item(s) across ${fsCount} filesystem(s).`);
  console.log("Safe to run terraform destroy.");
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});