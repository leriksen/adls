/**
 * cleanup.js — deletes all blobs under raw/eg-demo/ in the staging container.
 *
 * Usage:
 *   source terraform/env-dev.sh
 *   node cleanup.js
 */

const { BlobServiceClient } = require("@azure/storage-blob");
const { ClientSecretCredential } = require("@azure/identity");

const ACCOUNT_NAME = "leifadls";
const CONTAINER    = "staging";
const PREFIX       = "raw/eg-demo/";

const credential = new ClientSecretCredential(
  process.env.ARM_TENANT_ID,
  process.env.ARM_CLIENT_ID,
  process.env.ARM_CLIENT_SECRET
);

async function main() {
  const containerClient = new BlobServiceClient(
    `https://${ACCOUNT_NAME}.blob.core.windows.net`,
    credential
  ).getContainerClient(CONTAINER);

  console.log(`Listing blobs under ${CONTAINER}/${PREFIX} ...`);

  let count = 0;
  for await (const blob of containerClient.listBlobsFlat({ prefix: PREFIX })) {
    process.stdout.write(`  deleting ${blob.name} ... `);
    await containerClient.getBlobClient(blob.name).delete();
    console.log("done");
    count++;
  }

  console.log(`\nDeleted ${count} blob(s).`);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});